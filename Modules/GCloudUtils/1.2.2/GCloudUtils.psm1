Set-Alias -Name gkecred -Value Add-GKECredentials -Scope Global -Option AllScope
Set-Alias -Name agc -Value Add-GKECredentials -Scope Global -Option AllScope

Register-EngineEvent -SourceIdentifier 'Set-KubeContext' -Action { 
    $newProject = $Args[0] -replace '^.*_gke-'
    Set-GCloudConfigProject $newProject
}

[Kube]::ModularContextFile = [GCloud]::PathToProjectGkeMappings
[Kube]::AddContext = {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]$ContextName
    )
    Add-GKECredentials -SkipAddMapKey -ProjectID ($ContextName | Get-GCloudProjectIdFromGkeContext)
}
[Kube]::UpdateKubeMappedContexts()

$lastSyncDate = Get-Item ([GCloud]::PathToProjectCSV) | Select-Object -ExpandProperty LastWriteTime
if ( $lastSyncDate -lt (Get-Date).AddDays(-7) ) {
    Remove-GCloudUnusedGkeContexts
}