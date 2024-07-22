using namespace System.Text
function Remove-KubeContextsIfUnused {
    param (
        [Parameter(Mandatory)]
        [string[]]$PatternsToKeep,

        [Parameter(Mandatory,ParameterSetName='ContextsFromPSDataFile')]
        [Alias('LP,PSPath')]
        [ValidatePattern('.psd1$')]
        [string]$PSDataFilePath,

        [Parameter(Mandatory,ParameterSetName='ContextsAsStrings')]
        [string[]]$ContextsToHousekeep,

        [Parameter(ParameterSetName='housekeepKubeConfigFileOnly')]
        [switch]$HousekeepKubeConfigFileOnly
    )
    $allContexts = kubectl config get-contexts -o name
    $usedContexts = if ( $PSCmdlet.ParameterSetName -eq 'ContextsFromPSDataFile') {
        Import-PowerShellDataFile -LiteralPath $PSDataFilePath | Select-Object -ExpandProperty Values
    } else {
        $ContextsToHousekeep
    }

    $matchPatternsToKeep = $PatternsToKeep -join '|'
    $contextsToKeep = $usedContexts | Where-Object { $_ -match $matchPatternsToKeep}

    # Housekeep the kubectl config file
    if ( $allContexts ) {
        $allContexts | where { $_ -notmatch $matchPatternsToKeep } | foreach { kubectl config delete-context $_ }
    }
    # Housekeep the input contexts provided for checking
    if ( $usedContexts -and $PSCmdlet.ParameterSetName -ne 'housekeepKubeConfigFileOnly' ) {
        $usedContexts | Where-Object { $_ -notmatch $contextsToKeep } | Set-KubeMappedContexts
    }
}