<#
    .SYNOPSIS
        A PowerShell-alternative to the Bash "sed -i" in-file replacement, with hopefully easier syntax and actually useful output.
#>
Function Replace-StringInFile {

    [CmdletBinding()]
    Param (
        [alias('PSPath','LP')]
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string[]]$Path,
        [Parameter(Mandatory)]
        [string]$oldPattern,
        [Parameter(Mandatory)]
        [string]$newPattern,
        [int]$MaxDepth,
        [string]$Filter,
        [switch]$Recurse,
        [switch]$includeCommentedLines,
        [switch]$fast
    )
    begin {

        $params = @{ 'File' = $true}

        If ( ($Recurse) -or ($MaxDepth) ) {
            $params.Add( 'Recurse' , $true)
        }
    
        If ( ($MaxDepth) ) {
            $MaxDepth = ($MaxDepth - 1 )
            $params.Add( 'Depth' , $MaxDepth )
        }
    
        If ( $Filter ) {
            $params.Add( 'Filter' , $Filter)
        }
    
        If ($includeCommentedLines) {
            $noComments = $False
        }
        Else {
            $noComments = '^#'
        }
    
        Write-Host ""
        Write-Host 'Settings' -ForegroundColor 'red'
        Write-Host "`told string: $oldPattern"
        Write-Host "`tnew string: $newPattern"
        Write-Host ''
        Write-Host "`tBeginning processing..."
        Write-Host ''
    }
    process {
        ForEach ($p in $Path) {
            If ( $p -eq '*' ) {
                $p = '.'
            }
            $cleanPath = Convert-Path -LiteralPath $p
            Get-ChildItem $cleanPath @Params | ForEach {
                $file = $_.FullName
                
                $flagChangeMade = $False
                If ( !($fast) ) {
        
                    $contents = (( Get-Content $file ) | ForEach {
                        $line = $_
                        If ( $line -notmatch $noComments -and $line -match $oldPattern ) {
                            Write-Host ( $file + ': Replacing line...' ) -ForegroundColor 'yellow'
                            Write-Host ( "`t`t" + 'old: ' ) -ForegroundColor 'magenta' -NoNewLine;    Write-Host $line -ForegroundColor 'darkgreen'
        
                            $line = $line -replace $oldPattern, $newPattern
        
                            Write-Host ( "`t`t" + 'new: ' ) -ForegroundColor 'cyan' -NoNewLine;    Write-Host ( $line + [Env]::NL ) -ForegroundColor 'white'
                            $flagChangeMade = $true
                        }
                        $line
                    })
                    If ( $flagChangeMade ) { Set-Content $file -Value $contents }
                }
                Else {
                    Write-Host ("`t" + 'checking: ') -ForegroundColor 'yellow' -NoNewLine; $file
                    $tmpFile = New-TemporaryFile
                    $read = [System.IO.StreamReader]$file
                    $write = [System.IO.StreamWriter]$tmpFile
                    $newLine = [System.Text.StringBuilder]''
                    $lnumb = 1
                    try {
                        while ( ($line = $read.ReadLine()) -ne $null ){
                            $line = ($line + "`n")
                            If ( $lnumb % 100000 -eq 0 ){
                                If ( !($flagChangeMade) ) {
                                    $checkLine = $newLine.ToString()
                                    $newLine = ($newLine).Replace($oldPattern,$newPattern)
                                    If ( $checkLine -ne $newLine.ToString() ) {
                                        $flagChangeMade = $true
                                    }
                                }
                                Else {
                                    $newLine = ($newLine).Replace($oldPattern,$newPattern)
                                }
                                $write.Write($newLine)
                                $newLine = [System.Text.StringBuilder]''
                            }
                            $null = $newLine.Append($line)
                            $lnumb++
                        }
                        If ( !($flagChangeMade) ) {
                            $checkLine = $newLine.ToString()
                            $newLine = ($newLine).Replace($oldPattern,$newPattern)
                            If ( $checkLine -ne $newLine.ToString() ) {
                                $flagChangeMade = $true
                            }
                        }
                        Else {
                            $newLine = ($newLine).Replace($oldPattern,$newPattern)
                        }
                        $newLine = ($newLine).Replace($oldPattern,$newPattern)
                        $write.Write($newLine)
                    }
                    finally {
                        $newLine = [System.Text.StringBuilder]''
                        $write.Close()
                        $write.Dispose()
                        $read.Close()
                        $read.Dispose()
                    }
                    If ( $flagChangeMade ) {
                        Write-Host ("`t`t  " + 'String matches found! ') -ForegroundColor 'darkgreen' -NoNewLine; Write-Host ('File has been ') -NoNewLine; Write-Host 'updated' -ForeGroundColor 'Cyan' -NoNewLine; Write-Host ('.{0}' -f [Env]::NL)
                        $flagChangeMade = $False
                        Move-Item $tmpFile $file -Force
                    }
                    Else {
                        Write-Host ('{0}No string match found. File will be ignored.{1}' -f "`t`t  ", [Env]::NL )
                        Remove-Item $tmpFile
                    }
                }
            }
        }
    }
}
