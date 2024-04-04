Set-Alias -Name gkecred -Value Add-GKECredentials -Scope Global -Option AllScope

if ( !(Test-Path $HOME/.pwsh/gcloud/projects.csv ) ) { New-Item $HOME/.pwsh/gcloud/projects.csv -ItemType File -Force }
$psDriveGoogleProjects = 'gcp'

$GCloudParams = @{
    'PathToProjectCSV' = "$HOME/.pwsh/gcloud/projects.csv"
    'ProjectRoot' = "$HOME/.pwsh/gcloud/projects"
    'OrganizationNumber' = ''
    'FilterProjectNames' = '.*'
    'FilterProjectIds' = '.*'
    'MinimumSyncFrequency' = 0
}
[GCloud]::Set_GCloudProperties($GCloudParams)

<# INSTRUCTIONS
    Define your own parameters and run Set_GCloudProperties as performed above, e.g., in your profile or another module, then run the function:
    Sync-GCloudProjectsAsJob [-WaitOnMinimumFrequency]
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
if ( !(Get-Item "${psDriveGoogleProjects}:" -ErrorAction SilentlyContinue) ) {
    New-PSDrive -Name $psDriveGoogleProjects -Root ([GCloud]::ProjectRoot) -PSProvider FileSystem -Description 'Folder structure of projects in Google Cloud' -Scope Global
}

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