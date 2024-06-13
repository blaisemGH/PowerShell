Function Set-KubeContext {
    Param(
        [Parameter(Mandatory)]
        [ArgumentCompleter(
            {
                Param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                [Kube]::mapGcloudContexts.Keys | Where-Object {
                    [string]$_ -like "$wordToComplete*"
                } 
            }
        )]
        [string]$Context
    )
    $contextMap = [Kube]::mapGcloudContexts
    $contextName = If ( $Context -in $contextMap.Keys ) {
        $contextMap.$Context
    } else {
        $Context
    }
    kubectl config use-context $contextName
    Invoke-Expression ([Kube]::Initialize_KubeApiAutocomplete($true))
    Update-KubeCompletions
}
