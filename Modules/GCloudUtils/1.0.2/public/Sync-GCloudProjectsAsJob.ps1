<#
#>
Function Sync-GCloudProjectsAsJob {
    Param(
        [switch]$WaitOnMinimumFrequency
    )

    $lastSyncDate = Get-Item ([GCloud]::PathToProjectCSV) | Select-Object -ExpandProperty LastWriteTime
    $thresholdToNextSync = (Get-Date).AddSeconds(-[GCloud]::MinimumSyncFrequency)
    $timeRemaining = $lastSyncDate - $thresholdToNextSync
    if ( $WaitOnMinimumFrequency -and $lastSyncDate -gt $thresholdToNextSync) {
        Write-Verbose "Previous sync occurred more recently than the minimum sync frequency specified in the GCloud class. Canceling sync. Time remaining until next allowed sync: $($timeRemaining | Out-String)"
        return
    }
    Write-Warning 'Syncing gcloud projects in a background thread. If this is the first time, it may take a while and will consume some CPU from gcloud calls.
    Monitor the progress with Receive-Job -ID n [-Keep] to view the logging output. The ID can be obtained from Get-Job.
    Alternatively, Receive-Job GCloudSyncProjects [-Keep] will always locate this job.
    Note: -Keep will display the output without consuming it. Otherwise, future Receive-Jobs will only show new output since the previous Receive-Job.'

    $GCloudParams = [GCloud]::Config
    $gcloudSyncProjects = {
        $moduleHome = Split-Path $using:PSScriptRoot -Parent
        $manifest = Import-PowerShellDataFile $moduleHome/GCloudUtils.psd1
        Foreach ( $requiredModule in $manifest.RequiredModules ) {
            Import-Module $requiredModule -Force -DisableNameChecking
        }
        Foreach ( $nestedModule in $manifest.NestedModules ) {
            Import-Module (Join-Path $moduleHome $nestedModule) -Force -DisableNameChecking
        }
        ForEach ( $moduleScript in $manifest.ScriptsToProcess ) {
            . (Join-Path $moduleHome $moduleScript)
        }
        
        [GCloud]::Set_GCloudProperties($using:GCloudParams)
        Update-GCloudProjectRecord
        Update-GCloudProjectFS
    }

    If ( $PSVersionTable.PSEdition -eq 'Core' ) {
        Start-ThreadJob -ScriptBlock $gcloudSyncProjects -Name GCloudSyncProjects
    } Else { 
        Start-Job -ScriptBlock $gcloudSyncProjects -Name GCloudSyncProjects
    }
}