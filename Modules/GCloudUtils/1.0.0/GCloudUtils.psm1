Set-Alias -Name gkecred -Value Add-GKECredentials -Scope Global -Option AllScope

if ( !(Test-Path $HOME/.pwsh/gcloud/projects.csv ) ) { New-Item $HOME/.pwsh/gcloud/projects.csv -ItemType File -Force }

$GCloudParams = @{
    'PathToProjectCSV' = "$HOME/.pwsh/gcloud/projects.csv"
    'ProjectRoot' = "$HOME/.pwsh/gcloud/projects"
    'OrganizationNumber' = ''
    'FilterProjects' = '.*'
}
[GCloud]::Set_GCloudProperties($GCloudParams)

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