function Set-GCloudConfigProject {
    param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [string]$ProjectId
    )
    end {
        $project = $Input
        if ( $project -and $project -is [string] ) {
            gcloud config set project $project
            [GCloud]::CurrentProject = $project
        }
    }
}