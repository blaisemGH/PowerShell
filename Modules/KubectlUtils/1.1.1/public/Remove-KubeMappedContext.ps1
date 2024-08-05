using namespace System.Text
function Remove-KubeMappedContext {
    param (
        [Parameter(Mandatory)]
        [string[]]$PatternsToRemove,

        [Parameter(Mandatory,ParameterSetName='ContextsFromPSDataFile')]
        [Alias('LP,PSPath')]
        [ValidatePattern('.psd1$')]
        [string]$PSDataFilePath,

        [Parameter(Mandatory,ParameterSetName='ContextsAsStrings')]
        [string[]]$ContextsToHousekeep,

        [Parameter(ParameterSetName='housekeepKubeConfigFileOnly')]
        [switch]$HousekeepKubeConfigFileOnly
    )
    
    $matchPatternsToRemove = $PatternsToRemove -join '|'

    #region Housekeep the kubectl config file
    $removeKubeConfigFileContexts = if ( $PSCmdlet.ParameterSetName -eq 'ContextsAsStrings' ) {
        $ContextsToHousekeep
    } else {
        kubectl config get-contexts -o name
    }

    if ( $removeKubeConfigFileContexts ) {
        $removeKubeConfigFileContexts -eq $matchPatternsToRemove | foreach { kubectl config delete-context $_ }
    }
    #endregion

    #region housekeep cached context mappings
    if ( $PSCmdlet.ParameterSetName -eq 'ContextsFromPSDataFile') {
        $cachedContextMappings = Import-PowerShellDataFile -LiteralPath $PSDataFilePath
        $cachedContextMappings.GetEnumerator() |
            Where-Object { $_.Value -notmatch $matchPatternsToRemove} |
            Sort-Object Key |
            Set-KubeMappedContexts -FilePathOfContexts $PSDataFilePath
    }
    #endregion
}