Function Checkpoint-ModuleVersion {
<#
    .SYNOPSIS
        Checkpoint a module's files in one command, like taking a snapshot.
    .DESCRIPTION
        This function is intended to create a quick snapshot of your module development using basic cmdlets, then update it to the next version, so you can continue working immediately from a new checkpoint without interrupting your workflow. This is ideal for quick revision updates that you may not necessarily want to immediately push into your git repository until you've reached a new build/minor version, but you still want to version the latest change in case you need to roll it back.

		Each update also archives the current version's module files, e.g., to your folder synced with your git repository.

        It's similar to Save-Module; however, it is built with the following different logic:
            1. The module files aren't zipped, and PowerShellGet isn't invoked.
            2. The checkpoint will increment a version property (supports major/minor/build/revision) by 1.
                Technically, it is possible to increment multiple version properties at a time, or increment by more than 1.
                If an explicit version is needed, the parameter set versionExplicit is available.
            3. It preserves previous module versions of the same major and minor version in your PSModulePath, to provide an accessible record of changes to a major/minor version.
        
        Simply provide the ModuleName parameter and then either a combination of increments or the versionExplicit parameter.
        
		If you typically only work on 1 module at a time, the default value for ModuleName can be changed.
        The archiving parent directory can be set at the top of the script.
			* It defaults to your module's parent directory + repo/<ModuleName>.
			* If $env:repoDir is set, then it is archived to $env:repoDir + modules/$moduleName.
		If the archiving directory already contains a subfolder with the same version, it will prompt you to overwrite it.

	.EXAMPLE
		Checkpoint-ModuleVersion -ModuleName MyModule -RevisionIncrement 1
		
		Increment a module's revision version by 1. Recommend to use -WhatIf on the first use and -Confirm to walk through the steps.
		
    .EXAMPLE
        Checkpoint-ModuleVersion -ModuleName MyModule -BuildIncrement 1
        
        This would increment a module's build version by 1.
		
	.EXAMPLE
		Checkpoint-ModuleVersion -ModuleName MyModule -MinorIncrement 1
		
		This increments your minor version by 1.
		
		Furthermore, after the script archives the latest version, it will offer to clean up your module's base directory of lower minor versions.
			* There will be a prompt for removing each version directory.
			* It will not save these older folders before deletion, but if Checkpoint-ModuleVersion has been used for every version update, then you will have already archived these older versions.

    .EXAMPLE
        Checkpoint-ModuleVersion -ModuleName MyModule -VersionExplicit 4.3.2.1
        
        This would explicitly set the new module folder to version 4.3.2.1. I am not sure of the use case, but it's here just in case you need full control of setting the version.
#>
    [CmdletBinding(SupportsShouldProcess)]
    Param(
        #Name of the module to checkpoint
        [Parameter(ParameterSetName='Increment')]
        [Parameter(ParameterSetName='VersionExplicit')]
        [string]$ModuleName = 'batch',

        #Number to increment major version by
        [Parameter(ParameterSetName='Increment')]
        [int]$MajorIncrement,

        #Number to increment minor version by
        [Parameter(ParameterSetName='Increment')]
        [int]$MinorIncrement,

        #Number to increment build version by
        [Parameter(ParameterSetName='Increment')]
        [int]$BuildIncrement,

        #Number to increment revision version by
        [Parameter(ParameterSetName='Increment')]
        [int]$RevisionIncrement,

        #Explicitly set a new version.
        [Parameter(ParameterSetName='VersionExplicit')]
        [Version]$VersionExplicit
    )

    $incMa = $MajorIncrement
    $incMi = $MinorIncrement
    $incBu = $BuildIncrement
    $incRe = $RevisionIncrement
    If ( !(Get-Module $ModuleName) ) {
        Import-Module $ModuleName -ErrorAction Stop
    }

    $archiveModuleBaseDir = & {
        if ( $env:repoDir ) {
            Join-Path $env:repoDir modules/$ModuleName
        }
        else {
            Join-Path ( Split-Path (Split-Path $((Get-Module $ModuleName).ModuleBase) -Parent) -Parent) repo/$ModuleName
        }
    }

    $module = Get-Module $ModuleName | Where Version -eq ( Get-Module $ModuleName | Measure-Object Version -Maximum | Select-Object -ExpandProperty Maximum)
    $moduleVersion = $v = $module | Select-Object -ExpandProperty Version

	# Reassemble version to ensure all 4 version properties are involved (There was some reason I had to do this...)
	[Version]$currentVersion = $v.Major.ToString() + '.' + $v.Minor.ToString() + '.' + $v.Build.ToString() + '.' + $v.Revision.ToString()

	[Version]$newVersion = & {
        If ( $VersionExplicit ) {
            $VersionExplicit
        }
        Else {
            ($v.Major + $incMa).ToString() + '.' + ($v.Minor + $incMi).ToString() + '.' + ($v.Build + $incBu).ToString() + '.' + ($v.Revision + $incRe).ToString()
        }
    }

    If ( !$currentVersion -or !$newVersion ) {
        Throw "Error in deriving current and new versions! Current: $currentVersion | New: $newVersion"
    }

	# If a version property is empty, casting to the version type defaults it to -1, which doesn't make sense and would cause future increments to arrive at 0. The following code enforces a minimum of 0. Also, if you upgrade a higher version property, then it resets the lower version properties to 0, e.g., updating the minor version should reset build and revision to 0.
    $major = if ($newVersion.Major -lt 0) { 0 } else { $newVersion.Major }
    $minor = if ($newVersion.Minor -lt 0 -or (!$incMi -and $incMa) ){ 0 } else { $newVersion.Minor }
    $build = if ($newVersion.Build -lt 0 -or (!$incBu -and ($incMa -or $incMi)) ) { 0 } else { $newVersion.Build }
    $revision = if ($newVersion.Revision -lt 0 -or (!$incRe -and ($incMa -or $incMi -or $incBu)) ) { 0 } else { $newVersion.Revision }

    [Version]$cleanVersion = $major.ToString() + '.' + $minor.ToString() + '.' + $build.ToString() + '.' + $revision.ToString()

    If ( $cleanVersion -lt $currentVersion ) {
        Throw "Attempted to update module to an older version! Current Version: $currentVersion | Attempted new version: $cleanVersion"
    }

    Write-Host ('{0}Updating module "{1}" from version {2} to new version {3}' -f [Environment]::NewLine, $module.Name, $currentVersion, $cleanVersion) -Fore Green

	$progressDir = $null
	$progressCopy = $null
	$progressManifest = $null
	$archiveModuleDir = $archiveModuleBaseDir
    try {
        $normalErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = 'Stop'

        $moduleHome     = Split-Path "$($module.ModuleBase)" -Parent
        $oldModuleDir   = Split-Path "$($module.Path)" -Parent
        $newModuleDir   = Join-Path $moduleHome $cleanVersion
        $tempDir        = Join-Path $moduleHome tempUpdateDir

		# Create a temporary folder to copy module files into
        If ( $PSCmdlet.ShouldProcess( $tempDir, 'Create Directory') ) {
            New-Item $tempDir -ItemType Directory -Confirm:$false
            $progressDir = $true
        }

		# Copy current version's files into the temporary directory
        If ( $PSCmdlet.ShouldProcess("$oldModuleDir to $tempDir", 'Copy Directory') ) {
            Copy-Item -Path $oldModuleDir/* -Destination $tempDir -Recurse -Confirm:$false
        }

		# Update the module manifest in the temporary directory, then move the temporary directory back into your module path with the new version.
        $pathNewManifest = Join-Path $tempDir "$($module.Name).psd1"
        If ( $PSCmdlet.ShouldProcess( $pathNewManifest, 'Update module version') ) {
            Update-ModuleManifest -Path $pathNewManifest -ModuleVersion $cleanVersion -AliasesToExport '*' -CmdletsToExport '*' -FunctionsToExport '*' -VariablesToExport '*' -Confirm:$false
            Move-Item -Path $tempDir -Destination $newModuleDir -Confirm:$false
            Remove-Module $ModuleName -Force
            Import-Module $ModuleName -Force
            $progressManifest = $true
        }

		# Archive the current version's files to the archive directory
        If ( $PSCmdlet.ShouldProcess( "$oldModuleDir to $archiveModuleBaseDir", 'Archive and delete old module version dir' ) ){
            $archiveModuleDir = Join-Path $archiveModuleBaseDir $currentVersion

            If ( (Test-Path $archiveModuleDir) ) {
                Remove-Item $archiveModuleDir -Recurse -Confirm -Force
            }
            Copy-Item -Path $oldModuleDir -Destination $archiveModuleBaseDir -Recurse -Confirm:$false
            $progressCopy = $true

			# If a major or minor version has been incremented, offer to delete all folders in your module directory with a lower major/minor version.
            If ( $cleanVersion.Major -gt $currentVersion.Major -or $cleanVersion.Minor -gt $currentVersion.Minor ) {
                If ( $PSCmdlet.ShouldProcess( "All builds and revisions of $currentVersion in $moduleHome", 'Delete Directory' ) ){
                    Get-ChildItem $moduleHome -Exclude $cleanVersion.ToString() | Remove-Item -Recurse -Confirm:$true
                }
            }
        }
    }
    catch {
        $_

        Write-Host ('{0}Ended in ERROR! Rollback: Deleting any new directories and exiting script{1}' -f [Environment]::NewLine, [Environment]::NewLine ) -Fore Yellow

        If ( $progressCopy -and $archiveModuleDir -ne $archiveModuleBaseDir) {
            Remove-Item $archiveModuleDir -Recurse
            Remove-Item $newModuleDir -Recurse -Force
        }
        ElseIf ( $progressManifest ) {
            Remove-Item $newModuleDir -Recurse -Force
        }
        ElseIf ($progressDir) {
            Remove-Item $tempDir -Recurse -Force
        }
        break
    }
    finally {
        If ( $normalErrorActionPreference ) {
            $ErrorActionPreference = $normalErrorActionPreference
        }
    }
}
