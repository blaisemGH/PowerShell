function New-GCloudPamGrant {
    [CmdletBinding(DefaultParameterSetName='project')]
    param(
        [Parameter(Mandatory,ParameterSetName='organization')]
        [string]$Organization,

        [Parameter(Mandatory,ParameterSetName='folder')]
        [string]$Folder,

        [Parameter(Mandatory,Position=0,ParameterSetName='project')]
        [GCloudProjectIdCompletions()]
        [string]$ProjectId,
                
        [Parameter(Mandatory)]
        [GCloudPamEntitlementCompletions()]
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
    }
    $pamGrantCachePath = Join-Path ([Gcloud]::LocalCache) pam-grants
    if ( !(Test-Path $pamGrantCachePath) ) { New-Item $pamGrantCachePath -ItemType Directory }

    $existingGrant = Get-ChildItem $pamGrantCachePath | where name -match "^${Entitlement}_${tierType}_${tierValue}_${Location}_"
    $expiryDate = if ( $existingGrant ) { [datetime]::FromFileTime( ($existingGrant.BaseName -split '_')[-1] ) }

    if ( $expiryDate -and $expiryDate -gt (Get-Date) ) {
        Write-Verbose "Already have these permissions! See File $($existingGrant.FullName)"
    } else {
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

        $gcloudOutput = gcloud @arguments
        $scheduledActivation = $gcloudOutput | Select-String "scheduledActivationTime: '.*$"
    
        if ( $scheduledActivation ) {
            $activationDateTime = Get-Date ($scheduledActivation -split ':\s*', 2)[-1].Trim("'""")
            $newExpiryDateTime = $activationDateTime.AddSeconds($DurationInSeconds).ToFileTime()

            $cacheGrantRecord = Join-Path $pamGrantCachePath "${Entitlement}_${tierType}_${tierValue}_${Location}_${newExpiryDateTime}.log"
            
            $null = New-Item -Path $cacheGrantRecord -Value ($gcloudOutput -join "`n") -Force
        }
    }
}