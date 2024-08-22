function Get-GCloudProjectId {
    gcloud config get core/project
}

function Use-GCloudProjectId {
    Get-GCloudProjectId | Set-Clipboard
}