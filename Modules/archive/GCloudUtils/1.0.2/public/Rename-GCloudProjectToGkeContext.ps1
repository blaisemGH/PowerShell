function Rename-GCloudGkeContextToProjectId {
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidatePattern('_gke-[0-9a-z]{3}(-[0-9a-z]{4}){3}$')]
        [string]$Context
    )
    process {
        ($Context -split '_gke-')[-1]
    }
}