Set-Alias -Name gkecred -Value Add-GKECredentials -Scope Global -Option AllScope

#Removing private functions that were loaded via ScriptsToProcess.
Get-ChildItem (Join-Path $PSScriptRoot private) | Foreach {
	(
		(
			Get-Command $_.FullName |
				Select-Object -ExpandProperty ScriptBlock
		) -split "`r?`n" | Where {
			$_ -match 'function'
		}
	) -replace '.*function +(.*) +{.*', '$1' | ForEach {
		if ( test-path "function:$_") {
			remove-item "function:$_"
		}
	}
}