function Rename-KubeMappedContext {
    param (
        [Parameter(Mandatory)]
        [KubeMappedContextsCompletions()]
        [string]$OldContextName,
        [Parameter(Mandatory)]
        [string]$NewContextName
    )
    $mappedContexts = Import-PowerShellDataFile ([Kube]::ContextFile) -ErrorAction Stop
    $value = $mappedContexts.$OldContextName
    try {
        $mappedContexts.Add($NewContextName, $value)
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
    $mappedContexts.remove($OldContextName)

    Set-KubeMappedContexts -KubeContexts $mappedContexts
}