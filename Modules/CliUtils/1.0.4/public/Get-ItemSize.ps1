using namespace System.Collections.Generic
using namespace System.IO
<#
    .SYNOPSIS
        This function collects the size of files and folders and outputs them in a readable format, i.e., a format that is rounded up to the nearest unit for orders of magnitude of bytes. You may also force a specific unit by specifying it as an input parameter.
        
        Note that you can still sort on Length, as this is a hidden member and will work on directories unlike the normal Get-ChildItem.
#>
Function Get-ItemSize {
    [CmdletBinding()]
    Param (
        [Alias('PSPath')]
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true, Position=0)]
        $Path,
        [Parameter(Position=1)]
        [LengthUnit]$Unit,

        [switch]$CaseSensitive
    )
    begin {
        $enumerationOptions = [EnumerationOptions]::new()
        $enumerationOptions.AttributesToSkip = @('ReparsePoint')
    }
    process {
        $cleanPath = Get-Item $Path -Force | Where-Object {($_.Attributes -band 'ReparsePoint') -ne 'ReparsePoint'}
            
        ForEach ( $itemPath in $cleanPath ) {
            # Checks file or dir, because gci with recurse is very slow on compressed files. This deactivates recurse on files.
            #$recurse = (Get-Item $itemPath).PSIsContainer
            #$measure = Get-ChildItem $itemPath -File -Recurse:$recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum
            $enumerationOptions.RecurseSubdirectories = (Get-Item $itemPath -Force).PSIsContainer
            $measure = ([List[FileInfo]][Directory]::GetFiles( $itemPath, '*', $enumerationOptions)).Length | Measure-object -Sum
            If ( $Unit ) {
                [ItemSize]::new($itemPath, $measure.Sum, $Unit)
            }
            Else {
                [ItemSize]::new($itemPath, $measure.Sum)
            }
        }
    }
}
