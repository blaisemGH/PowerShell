using namespace System.IO
using namespace System.Text
using namespace System.Collections.Generic
using namespace System.Management.Automation.Runspaces

class CsvCompleter {
	[StreamReader]$streamReader
	[StreamWriter]$streamWriter
	[char]$fieldDelimiter
	[char]$textDelimiter
	[int]$streamWriterBufferLineCount
	[int]$parallelism

	[int]$totalBufferSize
	[int]$threadBufferSize
	static [Regex]$regexEscapeExistingDelimiters
	[string]$firstLine

	[StringBuilder]$fileContents
	[string[]]$stringIndexes
	[bool]$jobsExist = $false
	
	[list[PSCustomObject]]$runspaceInvocations = @()
	[RunspacePool]$runspacePool

	static [scriptblock] $add_delimiters = {
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
		$this.totalBufferSize = [Math]::Min(100000, $this.streamWriterBufferLineCount / 10)
		$this.threadBufferSize = $this.totalBufferSize / $this.parallelism
		[CsvCompleter]::regexEscapeExistingDelimiters = [regex]::new([regex]::Escape($this.textDelimiter), 'Compiled')
		
		$this.runspacePool = [RunspaceFactory]::CreateRunspacePool(1, $this.parallelism)
		$this.runspacePool.Open()
	}

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
			Throw "Could not recognize function argument TextDelimiter $($this.textDelimiter) in its byte represenation $byteRepresentation for conversion to a string that Java would recognize."
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
	
	
	[void] Set_StringIndexes () {
		if ( !$this.fileContents ) {
			$this.Read_CSVProperties()
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
	}

	[void] Initialize_CsvCompletion () {
		if ( !$this.stringIndexes ) {
			$this.Set_StringIndexes()
		}

		$firstCSVLine = $this.Complete_StringDelimiters($this.firstLine)
		[void]$this.fileContents.AppendLine( $firstCSVLine )
		Write-Host "`tIdentified string fields as the 0-based indexes $($this.stringIndexes -join ', ')"
	}

	[void] Start_CsvCompletion () {
		$this.Initialize_CsvCompletion()

		$lineCount = 1
		$bufferCollection = [List[Stringbuilder]]@()
		$bufferStringbuilder = [StringBuilder]''
		
		# I played around with ReadLine instead of async. Not sure which is better, but maybe async makes more sense?
		while ($null -ne ($line = $this.streamReader.ReadLineAsync().GetAwaiter().GetResult())) {#ReadLine())) {
			# If not trying to use Start-ThreadJob, i.e., a multi-threaded approach, you can uncomment the line below and delete all the code below that inside the while block, except linecount
			#$this.Update_FileContents($line)
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

		write-host "`tStreamReader finished final line of file. Checking for leftover lines in read buffer." -Fore Magenta
		# region Post-processing: Work up all buffers that may not have been emptied before the file ended.
		If ( (Get-Runspace).Count -gt 1 ) {
			Write-Host "`t`tFound $((Get-Runspace).Count - 1) additional runspaces. Awaiting their output..."
			$this.Checkpoint_RunspaceOutput()
		}
		If ( $bufferCollection ) {
			write-host "`t`tThe buffer collection is not empty. Looping through its contents now."
			Foreach ( $buffer in $bufferCollection ) {
				Write-Host "`t`t`tEmptying buffer to write batch..."
				$bufferContents = & ([CsvCompleter]::add_delimiters) $buffer $this.fielddelimiter $this.textdelimiter $this.stringIndexes ([CsvCompleter]::regexEscapeExistingDelimiters)
				$this.fileContents.Append( $bufferContents)
			}
			$bufferCollection = $null
		}
		If ( $bufferStringbuilder.ToString() ) {
			write-host "`t`tThe stringbuilder buffer has leftover lines. Adding these to write batch now."
			$bufferContents = & ([CsvCompleter]::add_delimiters) $bufferStringbuilder $this.fielddelimiter $this.textdelimiter $this.stringIndexes ([CsvCompleter]::regexEscapeExistingDelimiters)
			$this.fileContents.Append( $bufferContents.Trim([Environment]::NewLine) ) # This trim removes an empty line that stringbuilder automatically appends. Note this empty line is required if you are using the AppendLine method (otherwise the append won't be entered on a newline), which means you can only trim it when you are done using appendline.
		}

		Write-Host "`tReached end of processing. Writing the remaining write batch to output file.`r`n" -Fore Yellow
		$this.streamWriter.WriteLine($this.fileContents)
		$this.fileContents = [StringBuilder]''
	}
	
	# the main workhorse method to add text delimiters to strings.
	[string] Complete_StringDelimiters ([string] $line) {
		[list[string]]$lineFields = $line -split $this.fieldDelimiter
		Foreach ($index in $this.stringIndexes ) {
			try {
				$lineFields[$index] = $this.textDelimiter + [CsvCompleter]::regexEscapeExistingDelimiters.replace($lineFields[$index], "\$($this.textDelimiter)") + $this.textDelimiter
				#$lineFields[$index] = $this.textDelimiter + $lineFields[$index] + $this.textDelimiter
			}
			catch [ArgumentOutOfRangeException] { $lineFields.Add(  ('{0}{1}' -f $this.textDelimiter, $this.textDelimiter) )}
			catch {write-host ($_ | Out-string); write-host $index; write-host $linefields.count; write-host $linefields; write-host $line}
		}
		return ($lineFields -join $this.fieldDelimiter)
	}

	# The single-threaded approach to this class.
	[void] Update_FileContents ([string]$line ) {
		$csvLine = $this.Complete_StringDelimiters($line)
		[void]$this.fileContents.AppendLine($csvLine)
	}

	# The multi-threaded approach to this class. This method is a wrapper to call the async variation of the above method.
	[void] Start_AsyncUpdates ([list[StringBuilder]]$bufferCollection) {
		Write-Host "`tStaging $($this.totalBufferSize) processed lines to write batch."
		$this.Checkpoint_RunspaceOutput()

		Foreach ( $i in 0..($this.parallelism - 1) ) {
			
			$instancePS	= [PowerShell]::Create()
			$instancePS.RunspacePool = $this.runspacePool

			$buffer = $bufferCollection[$i]
			$instancePS.AddScript([CsvCompleter]::add_delimiters).
				AddArgument($buffer).
				AddArgument($this.fieldDelimiter).
				AddArgument($this.textDelimiter).
				AddArgument($this.stringIndexes).
				AddArgument([CsvCompleter]::regexEscapeExistingDelimiters)

			$this.runspaceInvocations.Add(
				[PSCustomObject]@{
					rsProcess = $instancePS
					handle = $instancePS.BeginInvoke()
				}
			)
		}
	}
	
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

	# Write loaded buffered results to output file.
	[void] Update_OutputFile () {
		[void]$this.streamWriter.WriteLineAsync($this.fileContents).GetAwaiter().GetResult()
		$this.fileContents = [StringBuilder]''
		Write-Host "`tWrote $($this.streamWriterBufferLineCount) lines to output file" -Fore Yellow
	}

}