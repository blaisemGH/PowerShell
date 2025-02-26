Function Set-KubeContext {
    Param(
        [Parameter(Mandatory)]
        [ArgumentCompleter(
            {
                Param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                [Kube]::MappedContexts.Keys | Where-Object {
                    [string]$_ -like "$wordToComplete*"
                }
            }
        )]
        [string]$Context
    )
    $contextMap = [Kube]::MappedContexts
    $contextName = If ( $Context -in $contextMap.Keys ) {
        $contextMap.$Context
    } else {
        $Context
    }
    $existingConfigContexts = kubectl config get-contexts -o name
    if ( $contextName -notin $existingConfigContexts ) {
        & ([Kube]::AddContext) $contextName
    }
    else {
        $output = kubectl config use-context $contextName
        Write-Verbose $output
    }

    $null = New-Event -SourceIdentifier 'Set-KubeContext' -EventArguments $contextName
    [Kube]::Initialize_KubeApiAutocomplete($true)
    #Update-KubeCompletions
}
