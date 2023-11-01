<#
	.DESCRIPTION
		This module is a performance-oriented utility for completing missing CSV content. Currently the module only provides the single function to add delimiters of your choice to fields identified as strings (based on the first line under the headers). This was developed in response to a customer who delivered CSV files with incomplete/broken string delimiters.
		
		Performance-wise, the bottlenecks are implemented entirely with .NET classes, and explicit runspaces (i.e., not ThreadJobs) are invoked for multi-threaded processing. I initially began with Start-ThreadJob, but I noticed my cpu utilization sucked; it struggled to stay around 2 cores occupied on my 12 core laptop. It was slow. I suspect Windows had an issue with efficiently allocating and recycling my threads, as this module can run through hundreds of cycles that are allocating and dropping threads every few seconds.

		I can't quite remember my run times, but I want to say, at 8 threads in parallel and a write buffer of 500k lines, the function took something like 20-40 minutes for a file with 38+ million lines and 32 columns, about half of which were string fields that needed to be wrapped. The memory pressure wasn't that high, a good several Gb. I piped a folder with around 40 csv files with collectively well over 75 million lines into this function, and it burned through them all in maybe around 40-80 minutes.

	.EXAMPLE
	
		Complete-CSVContents -Path x.csv -OutputDir ./outputDir/ -FieldDelimiter 9 -TextDelimiter '|' -ForceOverwriteOutputFile -StreamWriterBufferLineCount 500000 -ParallelBufferThreads 8
		
		The above is my last tested run. I processed an input file x.csv, which was output into ./outputDir/x.csv, which was force overwritten if it already existed. The input CSV had field delimiters that were tabs. This module wrapped every string field with pipes, e.g., |<string field>|. The string wrapping was multi-threaded to 8 cores, and every 500k lines it wrote down the output data into the output file.
	
#>
Function Complete-CSVContents {
	Param (
		[parameter(mandatory,position=0, ValueFromPipelineByPropertyName)]
		[alias('PSPath')]
		# The input csv file to be processed
		[string]$Path,
		[parameter(mandatory,position=1)]
		# The output directory, where the processed output CSV file will be copied into using the same name as the input CSV file.
		[string]$OutputDir,
		[parameter(mandatory,position=2)]
		[alias('d')]
		# The delimiter of the CSV file between fields/columns. Note this is auto converted to char, so use a 9 for tabs or 32 for empty spaces.
		[char]$FieldDelimiter,
		[parameter(mandatory,position=3)]
		[alias('td')]
		# The desired text delimiter that should wrap each string field.
		[char]$TextDelimiter,
		[alias('b')]
		# The number of lines that are processed before forcing a write to the output file. Note that this number serves a second purpose; namely, it is divided by 10 and this quotient defines the maximum number of rows distributed over the multi-threaded processing. For example, if you set this parameter to 100k and the parallelism to 10, then the CSV file will be processed line-by-line, with every 1000 lines being stored in a buffer. After 10k lines (= 10 buffers, i.e., 1 buffer for each thread), 10 threads will be started up, each to process 1 of the 10 buffers. The next 10k lines will immediately start reading the next 10k lines and batching every 1000 lines to a buffer. After these 10k lines are read, the script pauses until the remaining threads are finished with their respective batches and fetches their output data into memory, then starts up another 10 threads with the latest batch. This cycle continues until 100k total lines have been processed, whereupon the output data in memory is dumped to the StreamWriter for writing to the output file. The StreamWriter is asynchronous, so the next 100k lines immediately begin processing.
		$StreamWriterBufferLineCount=100000,
		[alias('force')]
		# Whether to overwrite any existing output file in the output directory
		[switch]$ForceOverwriteOutputFile,
		# The number of threads to allocate to the processing.
		[int]$ParallelBufferThreads = [Math]::Max(1,(Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors - 1)
	)
	process {
		$pathInputFile = (Resolve-Path $Path).ToString()
		$pathOutputDir = (Resolve-Path $OutputDir).ToString()
		$inputFileName = Split-Path $pathInputFile -Leaf
		
		If ( !(Test-Path $pathInputFile) ) {
			Throw "Could not find $pathInputFile!"
		}
		
		mkdir $pathOutputDir -ErrorAction SilentlyContinue
		
		$pathOutputFile = Join-Path $pathOutputDir $inputFileName
		if ( (Test-Path $pathOutputFile) -and !$ForceOverwriteOutputFile) {
			Throw "Designated output file $pathOutputFile already exists! Use -ForceOverwriteOutputFile to delete this file"
		}
		elseif ( (Test-Path $pathOutputFile) -and $ForceOverwriteOutputFile ) {
			Remove-Item $pathOutputFile
		}
		
		Write-Host "`r`nBeginning completion of file $pathInputFile!`r`n" -Fore Cyan
		$processStart = Get-Date

		try {
			$csvCompleter = [CsvCompleter]::New( $pathInputFile, $pathOutputFile, $FieldDelimiter, $TextDelimiter, $StreamWriterBufferLineCount, $ParallelBufferThreads)
			$csvCompleter.Read_CSVProperties()
			$csvCompleter.Set_StringIndexes()
			$csvCompleter.Start_CsvCompletion()
		}
		catch {
			Throw $_
		}
		finally {
			$csvCompleter.streamReader.Close()
			$csvCompleter.streamReader.Dispose()
			$csvCompleter.streamWriter.Close()
			$csvCompleter.streamWriter.Dispose()
			$csvCompleter.runspacePool.Close()
			$csvCompleter.runspacePool.Dispose()
			$csvCompleter = $null
			[System.GC]::Collect()
			[System.GC]::WaitForPendingFinalizers()
		}
		
		$processEnd = Get-Date
		Write-Host ( "Parsing completed and written to $pathOutputFile! Duration: " + ($processEnd - $processStart).TotalSeconds + ' seconds' ) -Fore Green
		sleep 1
	}
}