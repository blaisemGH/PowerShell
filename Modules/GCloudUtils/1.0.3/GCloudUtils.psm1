Set-Alias -Name gkecred -Value Add-GKECredentials -Scope Global -Option AllScope
Set-Alias -Name agc -Value Add-GKECredentials -Scope Global -Option AllScope

if ( !(Test-Path ([GCloud]::PathToProjectCSV) ) ) {
    New-Item ([GCloud]::PathToProjectCSV) -ItemType File -Force
}

if ( !(Test-Path ([GCloud]::ProjectRoot)) ) {
    New-Item ([GCloud]::ProjectRoot) -ItemType Directory -Force
}

if ( !(Test-Path ([GCloud]::PathToProjectGkeMappings)) ) {
    New-Item ([GCloud]::PathToProjectGkeMappings) -ItemType File -Value '@{}' -Force
}

$psDriveGoogleProjects = 'gcp'

$GCloudParams = @{
    'PathToProjectCSV' = [GCloud]::PathToProjectCSV
    'ProjectRoot' = [GCloud]::ProjectRoot
    'OrganizationNumber' = ''
    'FilterProjectNames' = '.*'
    'FilterProjectIds' = '.*'
    'MinimumSyncFrequency' = 0
}
[GCloud]::Set_GCloudProperties($GCloudParams)

<# INSTRUCTIONS
    Define your own parameters and run Set_GCloudProperties as performed above, e.g., in your profile or another module, then run the function:
    Sync-GCloudProjectsAsJob [-WaitOnMinimumFrequency]
    If calling within this psm1 file, then call it with the additional argument
    Sync-GCloudProjectsAsJob [-WaitOnMinimumFrequency] -ModuleHome $PSScriptRoot
    (see help Sync-GCloudProjectsAsJob)

    * This function will synchronize your GCloudProjects to a local filepath, default drive being gcp (see below).
        This local cache is used for:
            * faster lookups when running Add-GKECredentials with the -IDFromFS parameter
            * a convenient way to reference project IDs from the shell.
    * The sync runs gcloud for each directory in your project hierarchy, which takes a couple seconds per directory. Many projects will take a while.
    * Syncs are incremental. Already synced projects are skipped to save time. This means the first synchronization will be the longest.
    * Cached IDs are automatically removed, including orphaned parent folders (only if they're empty), if the ID no longer exists in `gcloud projects list`.
    * Rerun Sync-GCloudProjectsAsJob whenever you wish to update for new project IDs.
#>
if ( !(Test-Path "${psDriveGoogleProjects}:" -ErrorAction SilentlyContinue) ) {
    New-PSDrive -Name $psDriveGoogleProjects -Root ([GCloud]::ProjectRoot) -PSProvider FileSystem -Description 'Folder structure of projects in Google Cloud' -Scope Global
}

Register-EngineEvent -SourceIdentifier 'Set-KubeContext' -Action { 
    $newProject = $Args[0] -replace '^.*_gke-'
    gcloud config set project $newProject
    [GCloud]::CurrentProject = $newProject
}

if ( (Get-Module PSPrompt) -and !(Get-Module GCloudUtils) ) {
    $LineToPrintOn = if ( [PSPromptConfig]::PromptConfigsRight.values.Label -match 'KubectlUtils' ) { 2 } else { 1 }
    $getGCloudContext = { ': ' + [GCloud]::CurrentProject }
    $promptTemplateGetGCloudContext = @{
        Alignment = 'Right'
        ItemSeparator = ' '
        LineToPrintOn = $LineToPrintOn
        ForegroundColor = 'DarkKhaki'
        ContentFunction = $getGCloudContext
        label = 'GCloudUtilsSetContext'
    }
    [PSPromptConfig]::AddTemplate($promptTemplateGetGCloudContext)
}
Start-ThreadJob -ScriptBlock {
    gcloud config set survey/disable_prompts True
    gcloud config set disable_usage_reporting true
}
[Kube]::ModularContextFile = [GCloud]::PathToProjectGkeMappings
[Kube]::AddContext = {param([ValidateNotNullOrEmpty()]$ContextName) Add-GKECredentials -SkipAddMapKey -ProjectID ($ContextName | Get-GCloudProjectIdFromGkeContext)}
[Kube]::UpdateKubeMappedContexts()

Set-GCloudCompletion -ModuleHome $PSScriptRoot

#Removing private functions that were loaded via ScriptsToProcess.
#Get-ChildItem (Join-Path $PSScriptRoot private) | Foreach {
#	(
#		(
#			Get-Command $_.FullName |
#				Select-Object -ExpandProperty ScriptBlock
#		) -split "`r?`n" | Where {
#			$_ -match 'function'
#		}
#	) -replace '.*function +(.*) +{.*', '$1' | ForEach {
#		if ( test-path "function:$_") {
#			remove-item "function:$_"
#		}
#	}
#}