<#
    .SYNOPSIS
        A PowerShell-alternative to the Bash "sed -i" in-file replacement, with hopefully easier syntax and actually useful output.
#>
Function Replace-StringInFile {
    [CmdletBinding(SupportsShouldProcess)]
    Param (
        [alias('PSPath','LP')]
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string[]]$Path,
        [Parameter(Mandatory)]
        [Alias('oldString')]
        [string]$Pattern,
        [Parameter(Mandatory)]
        [Alias('newString')]
        [string]$ReplacementString,
        [int]$MaxDepth,
        [string]$Filter,
        [switch]$Recurse,
        [switch]$IncludeCommentedLines,
        [switch]$Fast,
        [switch]$Force
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

        If ($IncludeCommentedLines) {
            $noComments = $False
        }
        Else {
            $noComments = '^#'
        }

        if ($Force -and !$Confirm){
            $ConfirmPreference = 'None'
        }

        Write-Host ""
        Write-Host 'Settings' -ForegroundColor 'red'
        Write-Host "`told string: $Pattern"
        Write-Host "`tnew string: $ReplacementString"
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
                If ( !($Fast) ) {

                    $contents = (( Get-Content $file ) | ForEach {
                        $line = $_
                        If ( $line -notmatch $noComments -and $line -match $Pattern ) {
                            If ( $PSCmdlet.ShouldProcess( "Replace with $ReplacementString", $line ) ){
                                Write-Host ( $file + ': Replacing line...' ) -ForegroundColor 'yellow'
                                Write-Host ( "`t`t" + 'old: ' ) -ForegroundColor 'magenta' -NoNewLine; Write-Host $line -ForegroundColor 'darkgreen'

                                $line = $line -replace $Pattern, $ReplacementString

                                Write-Host ( "`t`t" + 'new: ' ) -ForegroundColor 'cyan' -NoNewLine; Write-Host ( $line + [Env]::NewLine ) -ForegroundColor 'white'
                                $flagChangeMade = $true
                            }
                        }
                        $line
                    })

                    If ( $flagChangeMade ) {
                        Set-Content $file -Value $contents
                    }
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
                            $line = ($line + [Environment]::NewLine )
                            If ( $lnumb % 100000 -eq 0 ){
                                If ( !($flagChangeMade) ) {
                                    $checkLine = $newLine.ToString()
                                    $newLine = $newLine -replace $Pattern, $ReplacementString
                                    If ( $checkLine -ne $newLine.ToString() ) {
                                        $flagChangeMade = $true
                                    }
                                }
                                Else {
                                    $newLine = $newLine -replace $Pattern, $ReplacementString
                                }
                                $write.Write($newLine)
                                $newLine = [System.Text.StringBuilder]''
                            }
                            $null = $newLine.Append($line)
                            $lnumb++
                        }
                        If ( !($flagChangeMade) ) {
                            $checkLine = $newLine.ToString()
                            $newLine = $newLine -replace $Pattern, $ReplacementString
                            If ( $checkLine -ne $newLine.ToString() ) {
                                $flagChangeMade = $true
                            }
                        }
                        Else {
                            $newLine = $newLine -replace $Pattern, $ReplacementString
                        }
                        $newLine = $newLine -replace $Pattern, $ReplacementString
                        $write.Write($newLine)

                        If ( $flagChangeMade ) {
                            Write-Host ("`t`t  " + 'String matches found! ') -ForegroundColor 'darkgreen' -NoNewLine; Write-Host ('File has been ') -NoNewLine; Write-Host 'updated' -ForeGroundColor 'Cyan' -NoNewLine; Write-Host ('.{0}' -f [Env]::NewLine)
                            $flagChangeMade = $False
                            Move-Item $tmpFile $file -Force -Confirm:$false
                        }
                        Else {
                            Write-Host ('{0}No string match found. File will be ignored.{1}' -f "`t`t  ", [Env]::NewLine )
                        }
                    }
                    finally {
                        $newLine = [System.Text.StringBuilder]''
                        $write.Close()
                        $write.Dispose()
                        $read.Close()
                        $read.Dispose()
                        If ( Test-Path $tmpFile ) {
                            Remove-Item $tmpFile -Confirm:$false
                        }
                    }
                }
            }
        }
    }
}
