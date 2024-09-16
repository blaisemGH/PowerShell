function Rename-GCloudGkeContextToProjectId {
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidatePattern('^gke(_[-a-z0-9]+){2}_gke-[-0-9a-z]+$')]
        [string]$Context
    )
    process {
        ($Context -split '_gke-')[-1]
    }
}