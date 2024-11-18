function Get-GCloudProjectId {
    param(
        [GCloudProjectIdCompletions()]
        [string]$ProjectId,
        [switch]$AsString
    )
    
    #gcloud config get core/project
    if ( !$ProjectId ) {
        return [GCloud]::CurrentProject
    }

    $output = gcloud projects list --format json | ConvertFrom-Json | Where-Object name -eq $ProjectId
    if ( $AsString ) {
        return $output | Select-Object Project_ID, Name, Project_Number
    }

    return $output
}

function Use-GCloudProjectId {
    Get-GCloudProjectId | Set-Clipboard
}