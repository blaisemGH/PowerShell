using namespace System.Text
function Remove-KubeContextsIfUnused {
    param (
        [Parameter(Mandatory,ParameterSetName='ContextsFromPSDataFile')]
        [Alias('LP,PSPath')]
        [ValidatePattern('.psd1$')]
        [string]$PSDataFilePath,

        [Parameter(Mandatory,ParameterSetName='ContextsAsStrings')]
        [string[]]$ContextsToHousekeep,
        
        [Parameter(Mandatory)]
        [string[]]$PatternsToKeep
    )
    $allContexts = kubectl config get-contexts -o name
    $usedContexts = if ( $PSCmdlet.ParameterSetName -eq 'ContextsFromPSDataFile') {
        Import-PowerShellDataFile -LiteralPath $PSDataFilePath
    } else {
        $ContextsToHousekeep
    }

    $matchPatternsToKeep = $PatternsToKeep -join '|'
    $contextsToKeep = $usedContexts.Values | Where-Object { $_ -notmatch $matchPatternsToKeep}
    
    if ( $usedContexts -and $contextsToKeep ) {
        $allContexts | where { $_ -notin $contextsToKeep } | foreach { kubectl config delete-context $_ }
        $usedContexts.GetEnumerator() |
            Where-Object { $_.Value -notin $contextsToKeep } | 
            Set-KubeMappedContexts
    }
}