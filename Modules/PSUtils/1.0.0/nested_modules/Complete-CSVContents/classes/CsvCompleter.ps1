using namespace System.IO
using namespace System.Text
using namespace System.Collections.Generic
using namespace System.Management.Automation.Runspaces

<#
	This class has 7 regions:
		1. First, its fields and constructor are defined. Of note is the static field $add_string_delimiters, which will be invoked every time a thread is started, i.e., a lot. It's very important this method is not abstracted any further. I originally had its loop abstracted into a second method, but the sheer number of method calls from every iteration of that loop multiplied by every active thread was crushing my Windows system; it inevitably crashed the PS Session.

		2. The method Read_CSVProperties stream reads meta information above the headers. I've commented out its calling invocation, as most CSVs probably won't have such meta information, but it could be easily reactivated and adapted if the use-case arises.

		3. The method Set_StringIndexes, which infers which fields are string fields and assigns them an index for reference in subsequent rows.

		4. Start_CsvCompletion, which begins parsing the body of the CSV data. The parsed data is loaded into a buffer, 1 buffer for each thread specified in the constructor. The size of each buffer is determined from the input arguments.

		5. Start_AsyncUpdates, which launches a thread for each buffer as it fills up. In this way, there is always a maximum number of runspacer in the background, each processing a buffer of lines, while the StreamReader is simultaneously reading the next lines to fill up the next buffer. Reading and processing are being performed asynchronously for maximum performance uptime.

		6. Checkpoint_RunspaceOutput, which activates every time the maximum number of threads have been allocated a buffer. At this point, the StreamReader is forced to pause, as all of the threads are busy processing their buffers, so there are no threads to allocate more data to. This method waits until all the threads are free again and meanwhile collects their output data into memory.

		7. Update_OutputFile, which writes all the output data in memory to the target output file. This occurs every set number of lines as specified in the input arguments, so as to keep memory pressure low while also not bottlenecking the performance behind too long a write. Note that the write is asynchronous, so the script will continue processing the next batch of lines while the write is performed.
#>
class CsvCompleter {
	[StreamReader]$streamReader
	[StreamWriter]$streamWriter
	[char]$fieldDelimiter
	[char]$textDelimiter
	[int]$streamWriterBufferLineCount
	[int]$parallelism

	[int]$totalBufferSize
	[int]$threadBufferSize
	[Regex]$regexEscapeExistingDelimiters
	[string]$firstLine

	[StringBuilder]$fileContents
	[string[]]$stringIndexes
	[bool]$jobsExist = $false
	
	[list[PSCustomObject]]$runspaceInvocations = @()
	[RunspacePool]$runspacePool

	# This is the anonymous function that will be invoked in every loop to add delimiters to each field.
	static [scriptblock] $add_string_delimiters = {
		Param (
			[System.Text.StringBuilder] $stringBuilderBuffer,
			[char] $fieldDelim,
			[char] $textDelim,
			[int[]] $indexOfStringFields,
			[System.Text.RegularExpressions.Regex]$regexEscapeExistingDelimiters
		)
		$manyLines = $stringBuilderBuffer.ToString().Trim([Environment]::NewLine) -split [Environment]::Newline
		$processManyRows = [System.Text.Stringbuilder]''
		$count = 0
		Foreach ($line in $manyLines) {
			[System.Collections.Generic.List[string]]$lineFields = $line -split $fieldDelim
			Foreach ($index in $indexOfStringFields ) {
				try {
					$lineFields[$index] = $textDelim + $regexEscapeExistingDelimiters.replace($lineFields[$index], "\$($textDelim)") + $textDelim
					#$lineFields[$index] = $textDelim + $lineFields[$index] + $textDelim
				}
				catch [ArgumentOutOfRangeException] { $lineFields.Add(  ('{0}{1}' -f $textDelim, $textDelim) )}
				catch {write-host ($_ | Out-string); write-host $index; write-host $linefields.count; write-host $linefields; write-host $line}
			}
			$csvLine = $lineFields -join $fieldDelim
			$null = $processManyRows.AppendLine($csvLine)
			$count += 1
		}
		Return $processManyRows.ToString()
	}

	CsvCompleter (
		[string]$inputFile,
		[string]$outputFile,
		[char]$fieldDelimiter,
		[char]$textDelimiter,
		[int]$writerBufferLineCount,
		[int]$parallelBufferThreads
	) {
		$readerOptions = [FileStreamOptions]::new()
		$readerOptions.Options = 'SequentialScan'
		$readerOptions.BufferSize = 1048576
		$readerOptions.Mode = 'Open'
		$this.streamReader = [StreamReader]::new($inputFile, [Encoding]::UTF8, $readerOptions)
		$this.streamWriter = [StreamWriter]::new($outputFile, $true, [Encoding]::UTF8, 1048576)
		$this.fieldDelimiter = $fieldDelimiter
		$this.textDelimiter = $textDelimiter
		$this.streamWriterBufferLineCount = $writerBufferLineCount
		
		$this.parallelism = $parallelBufferThreads
		$this.totalBufferSize = [Math]::Min(100000, [Math]::Round($this.streamWriterBufferLineCount / 10, 0))
		$this.threadBufferSize = [Math]::Round($this.totalBufferSize / $this.parallelism, 0)
		$this.regexEscapeExistingDelimiters = [regex]::new([regex]::Escape($this.textDelimiter), 'Compiled')
		
		$this.runspacePool = [RunspaceFactory]::CreateRunspacePool(1, $this.parallelism)
		$this.runspacePool.Open()
	}

	# A method I used to parse initial lines above the header. This has the benefit of both skipping through these lines to get to the header as well as parsing any meta information that may be needed. Can be adapted as needing for different csv property syntaxes.
	[void] Read_CSVProperties () {
		$csvProperties = [StringBuilder]''
		$delimiter = $this.fieldDelimiter
		$headerLine = ''

		while ($null -ne ($line = $this.streamReader.ReadLine())) {
			if ( $line -match '^field-separator' ) {
				$this.fieldDelimiter = $line.split('=')[1] -replace '\\t', [char]9
				$delimiter = $this.fieldDelimiter
			}

			if ( $line -match "^\w+$delimiter" ){
				$headerLine = $line
				break
			}
			elseif ( $line -match '^text-delimiter' ) {
				continue
			}
			else {
				[void]$csvProperties.AppendLine($line)
			}
		}
		$byteRepresentation = [byte][char]$this.textDelimiter
		if ( $byteRepresentation -lt 48 -and $byteRepresentation -notin '9','32' ) {
			Throw "Could not recognize function argument TextDelimiter $($this.textDelimiter) in its byte representation $byteRepresentation for conversion to a string that Java would recognize."
		}

		[string]$stringTextDelimiter = switch ($byteRepresentation) {
			9 {'\t'}
			32 {' '}
			DEFAULT {[char]$_}
		}
		[void]$csvProperties.AppendLine("text-delimiter=$stringTextDelimiter")
		[void]$csvProperties.AppendLine('')

		$this.fileContents = $csvProperties.ToString()
		$this.fileContents.AppendLine($headerLine)
	}
	
	# This method loops through the first row below the headers and identifies which fields are supposed to be strings. The index number of the field is recorded.
	[void] Set_StringIndexes () {
		if ( !$this.fileContents ) {
			#$this.Read_CSVProperties()
			$this.fileContents = [StringBuilder]''
		}

		$this.stringIndexes = @()
		$this.firstLine = $this.streamReader.ReadLine()
		$fields = $this.firstLine -split $this.fieldDelimiter

		Foreach ($index in 0..($fields.GetUpperBound(0)) ){
			$field = $fields[$index]

			$testDate = $field -as [datetime]
			$testInt = $field -as [int]
			$testFloat = ($field -replace '(?<=^[0-9]+),(?=[0-9]+$)', '.') -as [double]

			if ($testDate -or ($testInt -or $testInt -eq 0) -or ( $testFloat -or $testFloat -eq 0) ) {
				continue
			}
			elseif ( $field -is [string] ) {
				$this.stringIndexes += $index
			}
			else {
				throw "Error parsing field types. Field index $index with contents $field could not be typed."
			}
		}
		Write-Host "`tIdentified string fields as the 0-based indexes $($this.stringIndexes -join ', ')"
	}

	# Now that the metainformation above the header has been read and the string fields have been indexed, the next method begins parsing the remaining csv file data.
	[void] Start_CsvCompletion () {
		if ( !$this.stringIndexes ) {
			$this.Set_StringIndexes()
		}

		$lineCount = 1
		$bufferCollection = [List[Stringbuilder]]@()
		$bufferStringbuilder = [StringBuilder]''
		$bufferStringbuilder.AppendLine($this.firstLine)

		# I played around with ReadLine instead of async. Couldn't tell which is better, but maybe async sounds like it should be faster?
		while ($null -ne ($line = $this.streamReader.ReadLineAsync().GetAwaiter().GetResult())) {#ReadLine())) {
			# Add the current line to the current buffer. I tried doing this last in the while block to allow the readlineasync await to continue (and I set linecount's initial value to 2), but it seems to result in skipping some lines of the input file, i.e., very bad.
			$bufferStringbuilder.AppendLine($line)

			# Every $this.threadBufferSize lines add the current buffer of lines to the collection
			if ( $lineCount % $this.threadBufferSize -eq 0 ) {
				$bufferCollection.Add($bufferStringbuilder)
				$bufferStringbuilder = [StringBuilder]''
			}

			# Every $this.totalBufferSize lines empty out the buffer collection and convert its contents to output lines (delimited).
			if ( $lineCount % $this.totalBufferSize -eq 0 ) {
				$this.Start_AsyncUpdates($bufferCollection)
				$bufferCollection = [List[Stringbuilder]]@()
			}

			# Every $this.streamWriterBufferLineCount lines write the existing output lines to the output file.
			if ( $lineCount % $this.streamWriterBufferLineCount -eq 0) {
				$this.Update_OutputFile()
			}
			$lineCount += 1
		}

		Write-Host "`tStreamReader finished final line of file. Checking for leftover lines in read buffer." -Fore Magenta
		# region Post-processing: Work up all buffers that may not have been emptied before the file ended.
		If ( (Get-Runspace).Count -gt 1 ) {
			Write-Host "`t`tFound $((Get-Runspace).Count - 1) additional runspaces. Awaiting their output..."
			$this.Checkpoint_RunspaceOutput()
		}
		If ( $bufferCollection ) {
			write-host "`t`tThe buffer collection is not empty. Looping through its contents now."
			Foreach ( $buffer in $bufferCollection ) {
				Write-Host "`t`t`tEmptying buffer to write batch..."
				$bufferContents = & ([CsvCompleter]::add_string_delimiters) $buffer $this.fielddelimiter $this.textdelimiter $this.stringIndexes ($this.regexEscapeExistingDelimiters)
				$this.fileContents.Append( $bufferContents)
			}
			$bufferCollection = $null
		}
		If ( $bufferStringbuilder.ToString() ) {
			write-host "`t`tThe stringbuilder buffer has leftover lines. Adding these to write batch now."
			$bufferContents = & ([CsvCompleter]::add_string_delimiters) $bufferStringbuilder $this.fielddelimiter $this.textdelimiter $this.stringIndexes ($this.regexEscapeExistingDelimiters)
			$this.fileContents.Append( $bufferContents.Trim([Environment]::NewLine) ) # This trim removes an empty line that stringbuilder automatically appends. Note this empty line is required if you are using the AppendLine method (otherwise the append won't be entered on a newline), which means you can only trim it when you are done using appendline.
		}

		Write-Host "`tReached end of processing. Writing the remaining write batch to output file.`r`n" -Fore Yellow
		$this.streamWriter.WriteLine($this.fileContents)
		$this.fileContents = [StringBuilder]''
	}

	# This method is a wrapper to enable multi-threaded processing. It delegates partitions of the input file lines from StreamReader to a runspace (1 thread each), the number of runspaces given by the input argument's parallelism. Each runspace runs the code given in the static scriptblock (i.e., a PowerShell lambda function) property of this class.
	[void] Start_AsyncUpdates ([list[StringBuilder]]$bufferCollection) {
		Write-Host "`tStaging $($this.totalBufferSize) processed lines to write batch."
		$this.Checkpoint_RunspaceOutput()

		Foreach ( $i in 0..($this.parallelism - 1) ) {

			$instancePS	= [PowerShell]::Create()
			$instancePS.RunspacePool = $this.runspacePool

			$instancePS.AddScript([CsvCompleter]::add_string_delimiters).
				AddArgument($bufferCollection[$i]).
				AddArgument($this.fieldDelimiter).
				AddArgument($this.textDelimiter).
				AddArgument($this.stringIndexes).
				AddArgument($this.regexEscapeExistingDelimiters)

			$this.runspaceInvocations.Add(
				[PSCustomObject]@{
					rsProcess = $instancePS
					handle = $instancePS.BeginInvoke()
				}
			)
		}
	}

	# Retrieve data from the latest batch of runspaces started, pausing the script until all the runspaces have finished processing and released their threads.
	[void] Checkpoint_RunspaceOutput () {
		If ( $this.runspaceInvocations.handle ) {
			While ( $this.runspaceInvocations.handle.IsCompleted -Contains $false) {
			}
			If ( $this.runspaceInvocations.handle.IsCompleted -Contains $true ) {
				ForEach ( $invocation in $this.runspaceInvocations | Where {$_.Handle.IsCompleted} ) {
					[string]$content = $invocation.rsProcess.EndInvoke($invocation.handle)
					$this.fileContents.Append( $content )
				}
				$this.runspaceInvocations = @()
			}
		}
	}

	# Write loaded buffered results to output file asynchronously.
	[void] Update_OutputFile () {
		[void]$this.streamWriter.WriteLineAsync($this.fileContents).GetAwaiter().GetResult()
		$this.fileContents = [StringBuilder]''
		Write-Host "`tWrote $($this.streamWriterBufferLineCount) lines to output file" -Fore Yellow
	}

}