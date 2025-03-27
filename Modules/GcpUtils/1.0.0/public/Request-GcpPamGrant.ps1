function Request-GcpPamGrant {
    [CmdletBinding(DefaultParameterSetName='defaultToProject')]
    param(
        [Parameter(Mandatory,ParameterSetName='organization')]
        [string]$Organization,

        [Parameter(Mandatory,ParameterSetName='folder')]
        [string]$Folder,

        [Parameter(Mandatory,Position=0,ParameterSetName='project')]
        [GcpProjectIdCompletions()]
        [string]$ProjectId,

        [Parameter(Mandatory)]
        [GcpPamEntitlementCompletions()]
        [string]$Entitlement,

        [Parameter(Mandatory)]
        [int]$DurationInSeconds,

        [Parameter(Mandatory)]
        [string]$Location,

        [string]$Justification,

        [string[]]$EmailRecipients
    )

    $tierType, $tierValue = switch ($PSCmdlet.ParameterSetName) {
        organization { 'organization', $Organization }
        folder { 'folder', $Folder }
        project { 'project', $ProjectId }
        DEFAULT { 'project', (Get-GcpProjectId) }
    }
    $pamGrantCachePath = Join-Path ([Gcp]::LocalCache) pam-grants
    if ( !(Test-Path $pamGrantCachePath) ) { New-Item $pamGrantCachePath -ItemType Directory }

    $existingGrant = Get-ChildItem $pamGrantCachePath | where name -match "^${Entitlement}_${tierType}_${tierValue}_${Location}_"
    $expiryDate = if ( $existingGrant ) { [datetime]::FromFileTime( ($existingGrant.BaseName -split '_')[-1] ) }

    $argTier = "--$tierType=$tierValue"

    $argJustification = if ( $Justification ) { "--justification=""$Justification""" }
    $argEmails = if ( $EmailRecipients ) { "--additional-email-recipients=$($EmailRecipients -join ',')" }

    $arguments = @(
        'beta', 'pam', 'grants', 'create'
        $argTier
        "--entitlement=$Entitlement"
        "--requested-duration=${DurationInSeconds}s"
        "--location=$Location"
        $argJustification
        $argEmails
    )
    Write-Debug ('gcloud' + $arguments)

    if ( $expiryDate -and $expiryDate -gt (Get-Date) ) {
        Write-Verbose "Already have these permissions! See File $($existingGrant.FullName)"        
    } else {
        $gcpOutput = gcloud @arguments
        $scheduledActivation = $GcpOutput | Select-String "scheduledActivationTime: '.*$"

        if ( $scheduledActivation ) {
            $activationDateTime = Get-Date ($scheduledActivation -split ':\s*', 2)[-1].Trim("'""")
            $newExpiryDateTime = $activationDateTime.AddSeconds($DurationInSeconds).ToFileTime()

            $cacheGrantRecord = Join-Path $pamGrantCachePath "${Entitlement}_${tierType}_${tierValue}_${Location}_${newExpiryDateTime}.log"

            $null = New-Item -Path $cacheGrantRecord -Value ($gcpOutput -join "`n") -Force
        }
    }
}