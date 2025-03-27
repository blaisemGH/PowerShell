function Open-GcpConsoleWebpage {
    param(
        [Parameter(Mandatory)]
        [string]$ProjectId,

        [GcpConsoleArea]$ConsoleArea,

        [string]$Browser,
        [switch]$UrlOnly
    )

    $baseUrl = switch ($ConsoleArea) {
        ArtifactRegistry { 'https://console.cloud.google.com/artifacts' }
        ComputeDisks { 'https://console.cloud.google.com/compute/disks'}
        ComputeInstances { 'https://console.cloud.google.com/compute/instances'}
        ComputeSnapshots {'https://console.cloud.google.com/compute/snapshots'}
        Kubernetes {'https://console.cloud.google.com/kubernetes/list/overview'}
        Iam {'https://console.cloud.google.com/iam-admin/iam'}
        IamQuotas {'https://console.cloud.google.com/iam-admin/quotas'}
        PamEntitlements {'https://console.cloud.google.com/iam-admin/pam/entitlements/all'}
        StorageBuckets { 'https://console.cloud.google.com/storage/browser?prefix=&forceOnBucketsSortingFiltering=true' }
        SupportCases { 'https://console.cloud.google.com/support/cases' }
        DEFAULT {'https://console.cloud.google.com/welcome'}
    }

    $url = $baseUrl -match '\?' ? "${baseUrl}&project=$ProjectId" : "${baseUrl}?project=$ProjectId"

    if ( $UrlOnly ) {
        return $url
    }

    if ( $Browser ) {
        try {
            & $Browser $url
        } catch { 
            Write-Warning "Failed to open Browser. Is it in your path? Copying url to clipboard instead. Error message: $($_ | Out-String)"
            $url | Set-Clipboard
        }
    } else {
        Write-Host 'Browser not found! Copied URL to your clipboard instead.' -Fore Magenta
        $url | Set-Clipboard
    }

}