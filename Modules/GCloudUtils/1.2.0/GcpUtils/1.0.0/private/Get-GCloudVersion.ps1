function Get-GCloudVersion {
    [version]$gcloudVersion = (gcloud version 2> $null | Select-String 'SDK') -split ' (?=\d)' | Select-Object -last 1

    if ( !$gcloudVersion ) {
        $err = "Could not obtain gcloud version via [version]((gcloud version | Select-String 'SDK') -split ' (?=\d)' | Select-Object -last 1)"
        $PSCmdlet.ThrowTerminatingError([ErrorRecord]::new($err, $null, 'ObjectNotFound', $null))
    }

    return $gcloudVersion
}