function Get-GCloudGkeClusterInfoFromProjectId {
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$ProjectId
    )

    process {
        $gkeClusterInfo = (gcloud container clusters list --project $ProjectId 2> $null) -replace '\s{2,}', [char]0x2561 | ConvertFrom-Csv -Delimiter ([char]0x2561)

        if ( ! $gkeClusterInfo.Name ) {
            $err = [System.Management.Automation.ErrorRecord]::new("Empty output from command: gcloud container clusters list --project $ProjectId", $null, 'ObjectNotFound', $null)
            $PSCmdlet.ThrowTerminatingError($err)
        }

        $gkeContext = "gke_${ProjectId}_$($gkeClusterInfo.Location)_$($gkeClusterInfo.Name)"
        $gkeClusterInfo | Add-Member -Name Context -Value $gkeContext -MemberType NoteProperty
        
        $gkeClusterInfo
    }
}
