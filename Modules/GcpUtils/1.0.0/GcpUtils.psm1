#$importSource = @(
. "$PSScriptRoot/private/Get-GcloudVersion.ps1"
. "$PSScriptRoot/public/Update-GcpProjectRecord.ps1"
. "$PSScriptRoot/public/Update-GcpProjectFS.ps1"
. "$PSScriptRoot/public/Sync-GcpProjectsAsJob.ps1"
. "$PSScriptRoot/public/Sync-GkeContextMappings.ps1"
. "$PSScriptRoot/public/Get-GcpProjectId.ps1"
. "$PSScriptRoot/public/Request-GcpPamGrant.ps1"
. "$PSScriptRoot/public/Set-GcpConfigProject.ps1"
. "$PSScriptRoot/public/New-GcpProjectSession.ps1"
. "$PSScriptRoot/public/Open-GcpConsoleWebpage.ps1"
#)

#$importSource | foreach { . (Join-Path $PSScriptRoot $_) }

Set-Alias -Name ggp     -Value Get-GcpProjectId    -Scope Global -Option AllScope
Set-Alias -Name ugp     -Value Use-GcpProjectId    -Scope Global -Option AllScope
Set-Alias -Name opengcp -Value Open-GcpConsoleWebpage -Scope Global -Option AllScope

if ( !(Test-Path ([Gcp]::PathToProjectCSV) ) ) {
    New-Item ([Gcp]::PathToProjectCSV) -ItemType File -Force
}

if ( !(Test-Path ([Gcp]::ProjectRoot)) ) {
    New-Item ([Gcp]::ProjectRoot) -ItemType Directory -Force
}

if ( !(Test-Path ([Gcp]::PathToProjectGkeMappings)) ) {
    New-Item ([Gcp]::PathToProjectGkeMappings) -ItemType File -Value '@{}' -Force
}

$psDriveGoogleProjects = 'gcp'

$GcpParams = @{
    'PathToProjectCSV' = [Gcp]::PathToProjectCSV
    'ProjectRoot' = [Gcp]::ProjectRoot
    'OrganizationNumber' = ''
    'FilterProjectNames' = '.*'
    'FilterProjectIds' = '.*'
    'MinimumSyncFrequency' = 0
}
[Gcp]::SetGcpProperties($GcpParams)

<# INSTRUCTIONS
    Define your own parameters and run Set_GcpProperties as performed above, e.g., in your profile or another module, then run the function:
    Sync-GcpProjectsAsJob [-WaitOnMinimumFrequency]
    If calling within this psm1 file, then call it with the additional argument
    Sync-GcpProjectsAsJob [-WaitOnMinimumFrequency] -ModuleHome $PSScriptRoot
    (see help Sync-GcpProjectsAsJob)

    * This function will synchronize your GcpProjects to a local filepath, default drive being gcp (see below).
        This local cache is used for:
            * faster lookups when running Add-GKECredentials with the -IDFromFS parameter
            * a convenient way to reference project IDs from the shell.
    * The sync runs gcloud for each directory in your project hierarchy, which takes a couple seconds per directory. Many projects will take a while.
    * Syncs are incremental. Already synced projects are skipped to save time. This means the first synchronization will be the longest.
    * Cached IDs are automatically removed, including orphaned parent folders (only if they're empty), if the ID no longer exists in `gcloud projects list`.
    * Rerun Sync-GcpProjectsAsJob whenever you wish to update for new project IDs.
#>
if ( !(Test-Path "${psDriveGoogleProjects}:" -ErrorAction SilentlyContinue) ) {
    New-PSDrive -Name $psDriveGoogleProjects -Root ([Gcp]::ProjectRoot) -PSProvider FileSystem -Description 'Folder structure of projects in Google Cloud' -Scope Global
}

if ( (Get-Module PSPrompt) -and !(Get-Module GcpUtils) ) {
    $LineToPrintOn = if ( [PSPromptConfig]::PromptConfigsRight.values.Label -match 'KubectlUtils' ) { 2 } else { 1 }
    $getGcpContext = { ': ' + [Gcp]::CurrentProject }
    $promptTemplateGetGcpContext = @{
        Alignment = 'Right'
        ItemSeparator = ' '
        LineToPrintOn = $LineToPrintOn
        ForegroundColor = 'DarkKhaki'
        ContentFunction = $getGcpContext
        label = 'GcpUtilsSetContext'
    }
    [PSPromptConfig]::AddTemplate($promptTemplateGetGcpContext)
}

<#
$jobGcpConfig = Start-ThreadJob -ScriptBlock {
    gcloud config set survey/disable_prompts True 2>$null
    gcloud config set disable_usage_reporting true 2>$null
}
Register-ObjectEvent -InputObject $jobGcpConfig -EventName StateChanged -Action {
    Unregister-Event $EventSubscriber.SourceIdentifier
    Wait-Job -Id $EventSubscriber.SourceObject.Id | Remove-Job -Force
}
#>

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