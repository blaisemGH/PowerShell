function Remove-KubeMappedContext {
    param (
        [Parameter(Mandatory)]
        [KubeMappedContextsCompletions()]
        [alias('Context','c')]
        [string[]]$KubeContext
    )
    $mappedContexts = Import-PowerShellDataFile ([Kube]::ContextFile) -ErrorAction Stop
    $mappedContexts.Remove($KubeContext)
    
    Set-KubeMappedContexts -KubeContexts $mappedContexts
}