function Get-GCloudProjectIdFromGkeContext {
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidatePattern('^gke_.*_gke-[-a-z0-9]+$')]
        [string]$Context
    )
    process {
        Foreach ($gkeContext in $Context) {
            ($gkeContext -split '_gke-')[-1]
        }
    }
}