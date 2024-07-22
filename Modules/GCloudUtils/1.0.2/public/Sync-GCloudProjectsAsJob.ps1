using namespace System.Collections.Generic
Function Sync-GCloudProjectsAsJob {
    Param(
        [ValidateRange(1)]
        [int]$WaitOnMinimumFrequency = 0
    )

    $lastSyncDate = Get-Item ([GCloud]::PathToProjectCSV) | Select-Object -ExpandProperty LastWriteTime
    $thresholdToNextSync = (Get-Date).AddSeconds(-$WaitOnMinimumFrequency)
    $timeRemaining = $lastSyncDate - $thresholdToNextSync
    if ( $WaitOnMinimumFrequency -and $lastSyncDate -gt $thresholdToNextSync) {
        Write-Verbose "Previous sync occurred more recently than the minimum sync frequency specified in the GCloud class. Canceling sync. Time remaining until next allowed sync: $($timeRemaining | Out-String)"
        return
    }
    Write-Warning 'Syncing gcloud projects in a background thread. If this is the first time, it may take a while and will consume bandwith from gcloud calls.
    Monitor the progress with `Receive-Job -Name GCloudSyncProjects [-Keep]`.
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
        Sync-GCloudStandardGkeContextMappings

        $currentProjects = Get-ChildItem -LiteralPath ([GCloud]::ProjectRoot) -Recurse -File | Select-Object -ExpandProperty Name

        $kubeContexts = kubectl config get-contexts -o name
        $customMappedContexts = Import-PowerShellDataFile ([Kube]::ContextFile) | Select-Object -ExpandProperty Values
        $standardMappedContexts = Import-PowerShellDataFile ([GCloud]::PathToProjectGkeMappings) | Select-Object -ExpandProperty Values

        $contextsToKeep = $kubeContexts + $customMappedContexts + $standardMappedContexts | Sort-Object -Unique | Where { ($_ | Rename-GCloudGkeContextToProjectId) -notin $currentProjects }

        Remove-KubeContextsIfUnused -PatternsToKeep $contextsToKeep -PSDataFilePath ([Kube]::ContextFile)
        Remove-KubeContextsIfUnused -PatternsToKeep $contextsToKeep -PSDataFilePath ([GCloud]::PathToProjectGkeMappings)
    }

    If ( $PSVersionTable.PSEdition -eq 'Core' ) {
        Start-ThreadJob -ScriptBlock $gcloudSyncProjects -Name GCloudSyncProjects
    } Else { 
        Start-Job -ScriptBlock $gcloudSyncProjects -Name GCloudSyncProjects
    }
}