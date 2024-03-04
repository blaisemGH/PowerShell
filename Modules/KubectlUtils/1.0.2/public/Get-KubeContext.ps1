Function Get-KubeContext {
    Param(
        [ArgumentCompleter(
            {
                Param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                ([Kube]::mapGcloudContexts.Keys + '--current') | Where-Object {
                    [string]$_ -like "$wordToComplete*"
                }
            }
        )]
        [string]$Context = '--current'
    )
    $contextMap = [Kube]::mapGcloudContexts
    $targetContext = If ( $Context -eq '--current' ) {
        kubectl config view --minify -o json | ConvertFrom-Json | select -ExpandProperty contexts
    }
    ElseIf ( $Context -in $contextMap.Keys ) {
        kubectl config view -o json | ConvertFrom-Json | select -ExpandProperty contexts | where name -eq $contextMap.$Context
    }
    Else {
        kubectl config view -o json | ConvertFrom-Json | select -ExpandProperty contexts | where name -eq $Context
    }
    
    $fullContextName = $targetContext | Select-Object -ExpandProperty name
    $mapName = $contextMap.GetEnumerator() | where { $_.Value -eq $fullContextName } | Select-Object -ExpandProperty Key
    $contextName = If ( $mapName ) {
        $mapName
    }
    Else {
        $fullContextName
    }

    return [PSCustomObject]@{
        name = $contextName
        namespace = $targetContext.context.namespace
        cluster = $targetContext.context.cluster
    }
}
