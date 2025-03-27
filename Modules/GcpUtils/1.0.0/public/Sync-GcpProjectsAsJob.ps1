using namespace System.Collections.Generic
Function Sync-GcpProjectsAsJob {
    [CmdletBinding()]
    Param(
        [ValidateRange(1)]
        [int]$WaitOnMinimumFrequency = 0,
        [string]$ModuleHome = (Get-Module GcpUtils | Select-Object -ExpandProperty ModuleBase)
    )

    $lastSyncDate = Get-Item ([Gcp]::PathToProjectCSV) | Select-Object -ExpandProperty LastWriteTime
    $thresholdToNextSync = (Get-Date).AddSeconds(-$WaitOnMinimumFrequency)
    $timeRemaining = $lastSyncDate - $thresholdToNextSync
    if ( $WaitOnMinimumFrequency -and $lastSyncDate -gt $thresholdToNextSync) {
        Write-Verbose "Previous sync occurred more recently than the minimum sync frequency specified in the GCloud class. Canceling sync. Time remaining until next allowed sync: $($timeRemaining | Out-String)"
        return
    }
    Write-Warning 'Syncing gcloud projects in a background thread. If this is the first time, it may take a while and will consume bandwith from gcloud calls.
    Monitor the progress with `Receive-Job -Name GcpSyncProjects [-Keep]`.
    Note: -Keep will display the output without consuming it. Otherwise, future Receive-Jobs will only show new output since the previous Receive-Job.'

    $GcpParams = [Gcp]::Config
    $GcpSyncProjects = {
        $DebugPreference = $using:DebugPreference
        $WarningPreference = $using:WarningPreference
        $VerbosePreference = $using:VerbosePreference
        
        Write-Host 'Importing GcpUtils module' -Fore Yellow
        
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

        $importSource = @(
            'private/Get-GcloudVersion.ps1',
            'public/Update-GcpProjectRecord.ps1',
            'public/Update-GcpProjectFS.ps1',
            'public/Sync-GcpProjectsAsJob.ps1',
            'public/Sync-GkeContextMappings.ps1',
            'public/Get-GcpProjectId.ps1',
            'public/Request-GcpPamGrant.ps1',
            'public/Set-GcpConfigProject.ps1',
            'public/New-GcpProjectSession.ps1',
            'public/Open-GcpConsoleWebpage.ps1'
        )

        $importSource | foreach { . (Join-Path $moduleHome $_) }

        Write-Host 'Imported GcpUtils module.' -Fore Green

        [Gcp]::SetGcpProperties($using:GcpParams)

        Write-Host 'Initialized GcpUtils module' -Fore Green

        if ( [Gcp]::SyncProjectsPreparatoryFunction ) {
            & ([Gcp]::SyncProjectsPreparatoryFunction)
        }

        Update-GcpProjectRecord

        Update-GcpProjectFS

        Sync-GkeContextMappings
    }

    If ( $PSVersionTable.PSEdition -eq 'Core' ) {
        Start-ThreadJob -ScriptBlock $GcpSyncProjects -Name GcpSyncProjects
    } Else {
        Start-Job -ScriptBlock $GcpSyncProjects -Name GcpSyncProjects
    }
}