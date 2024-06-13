<#
    .SYNOPSIS
        This Function operates like a popd. It takes a numerical argument to move back a set number of directories.
#>
Function Back-Dir {
    
    [CmdletBinding()]
    Param (
        [ValidateRange(0)]
        [int]$NumberOfDirs = 1,
        [string]$StackName
    )
    $repeats = [Math]::Min($NumberOfDirs, (Get-Location -StackName $StackName -ErrorAction Stop).Count )
    ForEach ( $n in (1..$repeats) ) {
        Pop-Location
    }
}
