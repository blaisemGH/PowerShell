<#
    .DESCRIPTION
        This function takes an input string (may or may not be an existing filepath) and creates a new file with an updated increment. For example,
            * input: file-v01.txt | output: create file-v02.txt
            * input: file.txt | output: create file-v01.txt
            * input: file_02.txt | output: create file_v03.txt

        Notice that:
            1. The output file is created with the character 'v' for version. This is a default separator that can be set via the input parameter IncrementIdentifier. This must not be $null.
            2. In the last example, the increment is delimited by an _ instead of -. The script will infer the separator as long as it conforms to one of "_-." characters. If it cannot find one of these characters in the input string, it defaults to '-'

        If the input string refers to a file that already exists, then the script will examine the file's directory for the latest version number and begin incrementing from there. If it attempts to increment and finds the file name with the new increment already exists (if for some reason it's created by another process concurrently), then it will retry with the subsequent increment. After 10 such attempts, it will throw as a safeguard for a scenario that should never happen.
#>
Function Update-FileVersionIncrement {
    [OutputType([string])]
    Param(
        [Parameter(Mandatory,ValueFromPipelineByPropertyName)]
        [Alias('PSPath')]
        [string]$Path,
        [ValidateNotNullOrEmpty()]
        [string]$IncrementIdentifier = 'v',
        [int]$Retries = 0
    )
    Process {
    #Derive file attributes directory, name, basename, and extension.
    # Note this function will create the file if it doesn't exist; therefore, these attributes must be derivable from a string input only and not require the file already exist.
        $directory    = Split-Path $Path -Parent
        $fileName    = Split-Path $Path -Leaf
        $fileInfo    = Get-Item $fileName

        $null = $fileName -match '(?<baseName>.*)(?<extension>[.][a-zA-Z0-9]{2,})$'

        If ( $Matches.baseName -and $Matches.extension -and $directory -and $directory -notin '.','\','/') {
            $fileBaseName = $Matches.baseName -Split ("${IncrementIdentifier}[0-9]+$") | Select-Object -First 1
            $fileExtension = $Matches.extension

            If ( !($incrementSeparator = $fileBaseName -replace '.*([-_.])$','$1' -replace '.*[^-_.]$','') ){
                $incrementSeparator = '-'
            }
        }
        Else {
            Throw "FATAL ERROR! The function Update-FileVersionIncrement did not receive a correct input argument. It requires the full path containing the full directory path, filename, and file extension. Input: $Path"
        }
        
    # Calculate the current increment
        [int]$Retries = & {
            If ( Test-Path $directory ) {
                $file = Get-ChildItem $directory -Filter $fileBaseName* | Sort-Object | Select -Last 1
                    If ($file.Name -match "${IncrementIdentifier}(?<increment>[0-9]+)[.][a-zA-Z0-9]{2,}" ) {
                        $Matches.increment
                    }
                    Else { 
                        0
                    }
                }
            Else {
                0
            }
        }
        
    #Update the increment by 1, format it, and derive the new file basename and filepath
        $newIncrement = $Retries + 1
        $formatIncrement = '{0:d2}' -f $newIncrement
        $cleanBaseName = $fileBaseName.Trim($incrementSeparator)

        $newFileName = $cleanBaseName + $incrementSeparator + $IncrementIdentifier + $formatIncrement + $fileExtension
        $newFilePath = Join-Path $directory $newFileName
    
    #In case this version already exists, rerun the function. Will recurse up to 10 times.
        If ( (Test-Path $newFilePath) ){
            If ( $retryCounter -lt 10 ){
                $retryCounter += 1
                Return Update-FileVersionIncrement -Path $newFilePath -Retries $retryCounter -IncrementIdentifier $IncrementIdentifier
            }
            Else {
                Throw "FATAL ERROR! Cannot find a unique file name after 10 attempts. The function Update-FileVersionIncrement is looping to create file names that already exist. Current updated file name being attempted: $newFilePath"
            }
        }
        Else {
            Return $newFilePath
        }
    }
}
