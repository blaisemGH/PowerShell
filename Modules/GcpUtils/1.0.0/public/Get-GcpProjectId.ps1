function Get-GcpProjectId {
    param(
        [GcpProjectIdCompletions()]
        [string]$ProjectId,
        [switch]$AsString
    )

    #gcloud config get core/project
    if ( !$ProjectId ) {
        return [Gcp]::CurrentProject
    }

    $output = gcloud projects list --format json | ConvertFrom-Json | Where-Object name -eq $ProjectId
    if ( $AsString ) {
        return $output | Select-Object Project_ID, Name, Project_Number
    }

    return $output
}

function Use-GcpProjectId {
    Get-GcpProjectId | Set-Clipboard
}