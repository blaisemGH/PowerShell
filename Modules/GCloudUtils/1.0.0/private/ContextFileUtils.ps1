Function Update-ContextFileMap {
	Param (
		[Parameter(Mandatory)]
		[string]$ProjectName
	)
	
	$contextMap = [Kube]::mapGCloudContexts

	$kubeContext = kubectl config view -o json | ConvertFrom-Json | select -ExpandProperty Contexts | where name -match $ProjectName | select -ExpandProperty Name
	
	if ($contextMap.Values -contains $kubeContext ) {
		$confirm = Test-ReadHost -Query "Context map already contains a matching context. Would you like to replace it? [y/n]" -ValidationStrings 'y','yes','yeah','yea','ja','why are you still reading this?'
		if ( $confirm ) {
			$oldKey = $contextMap.GetEnumerator() | Foreach { if ( $_.Value -eq $kubeContext ) { $_.Key }}
			$contextMap.Remove($oldKey)
		}
		else {
			Throw "Exiting function now."
		}
	}

	$newKey = Read-Host "What string shortcut would you like to map to new context $kubeContext?"
	If ( $newKey ) {
		$contextMap.Add( $newKey, $kubeContext )
	}
	Else {
		[int]$lastPlaceholder = $contextMap.Keys | Where {$_ -match '^undecided-[0-9]+$' } | Sort-Object | select -last 1
		$newPlaceholder = 'undecided-{0:d2}' -f ($lastPlaceholder + 1)
		"Defaulting shortcut to $newPlaceholder"
		$contextMap.Add( $newPlaceholder, $kubeContext )
	}
	return $contextMap
}
	
	

Function Export-ContextFileAsPSD1 {
	Param(
		[Parameter(Mandatory,ValueFromPipeline)]
		[hashtable]$ContextMap
	)
	begin {
		$NL = [Environment]::NewLine

		[ValidateNotNullOrEmpty()]$pathContextFile = [Kube]::contextFile
		[ValidateNotNullOrEmpty()]$pathBackupContextFile = $pathContextFile -replace '^',' bkp_'
		[ValidateNotNullOrEmpty()]$pathTempContextFile = $pathContextFile -replace '^', 'failed_'
		
		$newContent = '@{' + $NL
	}
	process {
		Foreach ( $key in $ContextMap.Keys ) {
			$newContent += "`t" + $key + ' = ' + $contextMap.$key + $NL
		}
	}
	end {
		$newContent += '}'
		try {
			Copy-Item -Path $pathContextFile -Destination $pathBackupContextFile
			$newContent | Set-Content $pathContextFile -Force
			[Kube]::mapGCloudContexts = Import-PowerShellDatafile ([Kube]::contextFile)
		}
		catch {
			$newContent | Set-Content $pathContextFile -Force
			Throw "Failed to update context file at $pathContextFile.
			Created a backup file at $pathBackupContextFile
			Created a file of the failed update contents at $pathTempContextFile"
		}
	
		if ($?) {
			rm $pathBackupContextFile
		}
	}
}