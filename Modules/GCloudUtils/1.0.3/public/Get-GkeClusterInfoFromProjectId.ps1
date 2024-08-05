function Get-GkeClusterInfoFromProjectId {
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$ProjectId
    )

    process {
        $clusterGKEInfo = (gcloud container clusters list --project $ProjectId) -replace '\s{2,}', [char]0x2561 | ConvertFrom-Csv -Delimiter ([char]0x2561)

        if ( ! $clusterGKEInfo.Name ) {
            $err = [System.Management.Automation.ErrorRecord]::new("Empty output from command: gcloud container clusters list --project $ProjectId", $null, 'ObjectNotFound', $null)
            $PSCmdlet.ThrowTerminatingError($err)
        }

        $clusterGKEInfo
    }
}