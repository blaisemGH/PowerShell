Function Update-FileVersionIncrement {
    [OutputType([string])]
    Param(
        [Parameter(Mandatory,ValueFromPipelineByPropertyName)]
        [string]$FullName,
        [string]$incrementIdentifier = 'v',
        [int]$repeatCounter = 0
    )
    Process {
    #Derive file attributes directory, name, basename, and extension.
    # Note this function will create the file if it doesn't exist; therefore, these attributes must be derivable from a string input only and not require the file already exist.
    $filePath = $FullName
        $directory    = Split-Path $filePath -Parent
        $fileName    = Split-Path $filePath -Leaf

        $null = $fileName -match '(?<baseName>.*)(?<extension>[.][a-zA-Z0-9]{3,4})$'

        If ( $Matches.baseName -and $Matches.extension -and $directory -and $directory -notin '.','\','/') {
            $fileBaseName = $Matches.baseName -Split ("${incrementIdentifier}[0-9]+$") | Select-Object -First 1
            $fileExtension = $Matches.extension

            If ( !($fileSeparator = $fileBaseName -replace '.*([-_.])$','$1' -replace '.*[^-_.]$','') ){
                $fileSeparator = '-'
            }
        }
        Else {
            Throw "FATAL ERROR! The function Set-FileVersionIncrement did not receive a correct input argument. It requires the full path containing the full directory path, filename, and file extension. Input: $filePath"
        }
        
    # Calculate the current increment
        [int]$currentIncrement = & {
            If ( Test-Path $directory ) {
                $file = Get-ChildItem $directory -Filter $fileBaseName* | Sort-Object | Select -Last 1
                    If ($file.Name -match "${incrementIdentifier}(?<increment>[0-9]+)[.][a-zA-Z0-9]{3,4}" ) {
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
        $newIncrement = $currentIncrement + 1
        $formatIncrement = '{0:d2}' -f $newIncrement
        $cleanBaseName = $fileBaseName.Trim($fileSeparator)

        $newFileName = $cleanBaseName + $fileSeparator + $incrementIdentifier + $formatIncrement + $fileExtension
        $newFilePath = Join-Path $directory $newFileName
    
    #In case this version already exists, rerun the function. Will recurse up to 10 times.
        If ( (Test-Path $newFilePath) ){
            If ( $repeatCounter -lt 11 ){
                $repeatCounter += 1
                Return Set-FileVersionIncrement -filePath $newFilePath -repeatCounter $repeatCounter -incrementIdentifier $incrementIdentifier
            }
            Else {
                Throw "FATAL ERROR! Cannot find a unique file name. The function Set-FileVersionIncrement is looping to create file names that already exist. Current updated file name being attempted: $newFilePath"
            }
        }
        Else {
            Return $newFilePath
        }
    }
}
