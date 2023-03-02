Function Export-PowerShellDataFile {
    Param(
        [Parameter(Mandatory,ValueFromPipeline)]
        $inputObject,
        [Parameter(Mandatory)]
        [string]$Path,
        [switch]$Force
    )
    
    begin {
        If ( (Test-Path $Path) -and !$Force) {
            Throw "A file already exists at $Path"
        }
        $out = @()
    }
    process {
        $out += ConvertTo-PowerShellDataFile $inputObject
    }
    end {
        Set-Content -Path $Path -Value $out -Force
    }
}

Function ConvertTo-PowerShellDataFile {
    Param(
        [Parameter(Mandatory,ValueFromPipeline)]
        $inputObject = $null,
        [int]$indent = 0
    )
    begin {
        $indent = [Math]::Max(0, $indent)
    }
    Process {
        If ( $inputObject -is [hashtable] ) {
            Write-Output ( '  ' * $indent + '@{' + [Environment]::NewLine )

            ForEach ($key in $inputObject.Keys ) {
                $formatKey = $key -replace '^([^''"]?[^''"]*[-_.][^''"]*)$', '''$1'''
                $value = ConvertTo-PowerShellDataFile $inputObject.$key -indent ($indent + 1)
                # The replaces remove whitespace between the = and the value. The '  ' * $indent works great on newlines but creates this extra whitespace on same lines.
                Write-Output ((('  ' * ($indent + 1)) + $formatKey + ' = ' + ($value -replace '= [ ]*', '= ') + [Environment]::NewLine) -replace '= [ ]*','= ')
            }

            Write-Output ( [Environment]::NewLine + ('  ' * $indent) + '}' + [Environment]::NewLine)
        }

        ElseIf ( $inputObject -is [System.Collections.IEnumerable] -and $inputObject -isnot [string] ) {
            Write-Output ( '  ' * $indent + '@(' + [Environment]::NewLine )

            Foreach ( $object in $inputObject ) {
                $addMissingIndent = $null
                if ( $object -is [hashtable] ) {
                    Write-Output [Environment]::NewLine
                    $addMissingIndent =  ('  ' * ($indent - 1))
                }
                Write-Output ($addMissingIndent + (ConvertTo-PowerShellDataFile $object -indent ($indent + 1)) )
            }

            Write-Output ( [Environment]::NewLine + ('  ' * $indent) + ')' + [Environment]::NewLine)
        }
        
        ElseIf ( $inputObject -is [psobject] ) {
            Write-Output ( '  ' * $indent + '@{' + [Environment]::NewLine )

            Foreach ( $property in $inputObject.psobject.properties ) {
                $value = If ( !$property.value) {
                    "''"
                }
                Else {
                    (ConvertTo-PowerShellDataFile $property.value -Indent ($indent + 1)) #-replace '^[ ]*(\n)?', '$1'
                }
                Write-Output ((('  ' * ($indent + 1)) + $property.name + ' = ' + ($value -replace '= [ ]*', '= ') + [Environment]::NewLine) -replace '= [ ]*','= ')
            }

            Write-Output ( [Environment]::NewLine + ('  ' * $indent) + '}' + [Environment]::NewLine)
        }
        
        Else {
            $openHereString, $closeHereString = $null
            If ( $inputObject -is [string] ) {
                #Lines containing a newline, single quote, or backtick cause parsing issues. Therefore I wrap them in here strings to parse them literally.
                If ( $inputObject -match [Environment]::NewLine -or $inputObject -match '(?<!^'')[''](?!$)' -or $inputObject -match '[``]') {
                    $openHereString = [Environment]::NewLine + "@'" + [Environment]::NewLine
                    $closeHereString = [Environment]::NewLine + "'@"
                }
                #Replace regex: If the object isn't wrapped in quotes, then wrap it in single quotes. All \n and \t are converted to newlines and tabs, respectively.
                Write-Output ( $openHereString + '  ' * $indent + ($inputObject -replace '^([^''"]?[^''"]*[^''"]?)$', '''$1''' -replace '\\n', [Environment]::NewLine -replace '\\t',"`t" ) + $closeHereString )
            }
            Else {
                Write-Output ( '  ' * $indent + $inputObject )
            }
        }
    }
}
