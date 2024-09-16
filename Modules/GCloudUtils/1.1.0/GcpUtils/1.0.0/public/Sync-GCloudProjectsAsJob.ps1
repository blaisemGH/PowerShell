using namespace System.Collections.Generic
Function Sync-GCloudProjectsAsJob {
    [CmdletBinding()]
    Param(
        [ValidateRange(1)]
        [int]$WaitOnMinimumFrequency = 0,
        [string]$ModuleHome = (Get-Module GCloudUtils | Select-Object -ExpandProperty ModuleBase)
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
        Write-Host 'Importing GCloud module' -Fore Yellow
        
        $moduleHome = $using:ModuleHome
        $manifest = Import-PowerShellDataFile $moduleHome/GcpUtils.psd1
        Write-Host 'Imported manifest file'
        Foreach ( $requiredModule in $manifest.RequiredModules ) {
            Write-host "Importing required module $requiredModule"
            $oldVerbosePreference = $VerbosePreference
            $VerbosePreference = 'Continue'
            Import-Module $requiredModule -Force -DisableNameChecking -Verbose
            $VerbosePreference = $oldVerbosePreference
        }
        
        Foreach ( $nestedModule in $manifest.NestedModules ) {
            Write-Host "Importing nested module $nestedModule"
            Import-Module (Join-Path $moduleHome $nestedModule) -Force -DisableNameChecking -Verbose
        }
        
        ForEach ( $moduleScript in $manifest.ScriptsToProcess ) {
            Write-Host "Importing script $moduleScript"
            . (Join-Path $moduleHome $moduleScript)
        }
        

        Write-Host 'Imported GCloud module.' -Fore Green

        [GCloud]::SetGCloudProperties($using:GCloudParams)

        Write-Host 'Initialized GCloud module' -Fore Green
        Update-GCloudProjectRecord
        Write-Host 'Finished updating GCloud project record. See [GCloud]::PathToProjectCSV' -Fore Cyan

        Update-GCloudProjectFS
        Write-Host 'Finished Updating local filesystem cache. See [GCloud]::ProjectRoot' -Fore Cyan

        Write-Host 'Beginning to write standardized mappings for Gke contexts. This may take a while.' -Fore Yellow
        Sync-GCloudStandardGkeContextMappings
        
        Write-Host 'Performing housekeeping to remove nonexistent contexts.' -Fore Magenta

        $currentProjects = Get-ChildItem -LiteralPath ([GCloud]::ProjectRoot) -Recurse -File | Select-Object -ExpandProperty Name

        $kubeContexts = kubectl config get-contexts -o name
        $customMappedContexts = Import-PowerShellDataFile ([Kube]::ContextFile) | Select-Object -ExpandProperty Values
        $standardMappedContexts = Import-PowerShellDataFile ([GCloud]::PathToProjectGkeMappings) | Select-Object -ExpandProperty Values

        $contextsToRemove = $kubeContexts + $customMappedContexts + $standardMappedContexts |
            Sort-Object -Unique |
                Where {
                    $_ -match '^gke(_[-a-z0-9]+){2}_gke-[-0-9a-z]+$' -and
                    ($_ | Rename-GCloudGkeContextToProjectId) -notin $currentProjects
                }

        if ( $contextsToRemove ) {
            Write-Host "Removing the following contexts for housekeeping: `n`n$( $contextsToRemove | Out-String )"
            Remove-KubeMappedContext -PatternsToRemove $contextsToRemove -PSDataFilePath ([Kube]::ContextFile)
            Remove-KubeMappedContext -PatternsToRemove $contextsToRemove -PSDataFilePath ([GCloud]::PathToProjectGkeMappings)
        }
        else {
            Write-Host "Housekeeping found no unused contexts to remove!"
        }
    }

    If ( $PSVersionTable.PSEdition -eq 'Core' ) {
        Start-ThreadJob -ScriptBlock $gcloudSyncProjects -Name GCloudSyncProjects
    } Else { 
        Start-Job -ScriptBlock $gcloudSyncProjects -Name GCloudSyncProjects
    }
}