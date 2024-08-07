Function Get-KubeContextInfo {
    Param(
        [ArgumentCompleter(
            {
                Param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                ([Kube]::MappedContexts.Keys + '--current') | Where-Object {
                    [string]$_ -like "$wordToComplete*"
                }
            }
        )]
        [string]$Context = '--current',
        
        [Alias('PSPath')]
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$KubeConfigFile = $env:KUBECONFIG
    )
    process {
        $kubeConfigPath = if ( $KubeConfigFile ) { $KubeConfigFile } else {Convert-Path ~/.kube/config }
    
        $contextMap = [Kube]::MappedContexts
        $targetContext = & {
            If ( $Context -eq '--current' ) {
                # For getting the current namespace, I manually parse the kube config file instead of using kubectl commands, because it saves 135ms. This is huge  if you're using this function in your prompt to track the current namespace. The original kubectl implementation is still provided below.
                $name = (Select-String -path $kubeConfigPath '^current-context:.*').line -split ': ' | Select-Object -last 1
                $relevantContext = (Select-String -path $kubeConfigPath "  name: $name" -Context 3).Context.Precontext 
                [PSCustomObject]@{
                    name = $name
                    context = @{
                        namespace = ($relevantContext | sls '^\s*namespace:' | select -exp line -first 1) -split ': ' | select -last 1
                        cluster = ($relevantContext | sls '^\s*cluster:' | select -exp line -first 1) -split ': ' | select -last 1
                    }
                }
                #kubectl config view --minify -o json | ConvertFrom-Json | select -ExpandProperty contexts
            }
            ElseIf ( $Context -in $contextMap.Keys ) {
                kubectl config view -o json | ConvertFrom-Json | select -ExpandProperty contexts | where name -eq $contextMap.$Context
            }
            Else {
                kubectl config view -o json | ConvertFrom-Json | select -ExpandProperty contexts | where name -eq $Context
            }
        }
        
        $fullContextName = $targetContext | Select-Object -ExpandProperty name
        $mapName = $contextMap.GetEnumerator() | where { $_.Value -eq $fullContextName } | Sort-Object { $_.Key.Length } | Select-Object -ExpandProperty Key -First 1
        
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
}
