<#
    .SYNOPSIS
        A diff function I copied/modified several years ago but ended up never using. It may need a redesign.
#>
Function Compare-FileDiff {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)]
            $Path1,
        [Parameter(Mandatory=$true)]
            $Path2,
        [Parameter(Mandatory=$true)]
            $lineFlag,
        [Parameter(Mandatory=$true)]
            $patternStart,
        [Parameter(Mandatory=$true)]
            $patternEnd
    )

    $arrFile1 = (New-Object -TypeName System.Collections.Generic.List[string])
    Get-Content $Path1 | ForEach {
        $line = $_
        If ( $line -match $lineFlag ) {
            $arrFile1.Add( ($line.Substring(   ( $line.IndexOf($patternStart) + 1 ) , ( $line.IndexOf($patternEnd) - ($line.IndexOf($patternStart) + 1) )   )) )
        }
    }

    $arrFile2 = (New-Object -TypeName System.Collections.Generic.List[string])
    Get-Content $Path2 | ForEach {
        $line = $_
        If ( $line -match $lineFlag ) {
            $arrFile2.Add( ($line.Substring(   ( $line.IndexOf($patternStart) + 1 ) , ( $line.IndexOf($patternEnd) - ($line.IndexOf($patternStart) + 1) )   )) )
        }
    }


    Write-Host ( '{0}{1}{2}Strings in file 2 that are missing in file 1:{3}' -f [Env]::NL, [Env]::NL, [Env]::NL, [Env]::NL )

    $arrCompare2 = (New-Object -TypeName System.Collections.Generic.List[string])
    ForEach ( $table in $arrFile2 ) {
        If ( $table -notin $arrFile1 ) {
            $arrCompare2.Add( "missing in file1: $table")
        }
        Else {
            $arrCompare2.Add( "matches in file1: $table")
        }
    } $arrCompare2 | Sort-Object -Descending

    Write-Host ( '{0}Strings in file1 that are missing in file 2{1}:' -f [Env]::NL, [Env]::NL )

    $arrCompare1 = (New-Object -TypeName System.Collections.Generic.List[string])
    ForEach ( $table in $arrFile1 ) {
        If ( $table -notin $arrFile2 ) {
            $arrCompare1.Add( "missing in file2: $table")
        }
        Else {
            $arrCompare1.Add( "matches in file2: $table")
        }
    } $arrCompare1 | Sort-Object -Descending

    Remove-Variable arrFile1
    Remove-Variable arrFile2
    Remove-Variable arrCompare1
    Remove-Variable arrCompare2

}
