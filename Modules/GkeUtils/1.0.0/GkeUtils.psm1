$importSource = 'public/ContextFileUtils.ps1', 'public/Add-GKECredentials.ps1',
               'public/Remove-GkeContextsIfUnused.ps1',
               'public/Get-GkeClusterInfoFromProjectId.ps1',
               'public/Get-GcpProjectIdFromGkeContext.ps1',
               'public/Set-GkeContext.ps1',
               'public/Rename-GkeContextToProjectId.ps1'

$importSource.ForEach({
    . (Join-Path $PSScriptRoot $_)
})

Set-Alias -Name gkecred -Value Add-GKECredentials -Scope Global -Option AllScope
Set-Alias -Name agc -Value Add-GKECredentials -Scope Global -Option AllScope

Register-EngineEvent -SourceIdentifier 'Set-KubeContext' -Action { 
    $newProject = $Args[0] -replace '^.*_gke-'
    Set-GkeConfigProject $newProject
}

[Kube]::ModularContextFile = [Gcp]::PathToProjectGkeMappings
[Kube]::AddContext = {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]$ContextName
    )
    Add-GKECredentials -SkipAddMapKey -ProjectID ($ContextName | Get-GkeProjectIdFromGkeContext)
}
[Kube]::UpdateKubeMappedContexts()

$lastSyncDate = Get-Item ([Gcp]::PathToProjectCSV) | Select-Object -ExpandProperty LastWriteTime
if ( $lastSyncDate -lt (Get-Date).AddDays(-7) ) {
    Remove-GkeContextsIfUnused
}