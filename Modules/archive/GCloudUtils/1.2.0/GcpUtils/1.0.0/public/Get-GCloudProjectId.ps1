function Get-GCloudProjectId {
    #gcloud config get core/project
    [GCloud]::CurrentProject
}

function Use-GCloudProjectId {
    Get-GCloudProjectId | Set-Clipboard
}