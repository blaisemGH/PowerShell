#
# Module manifest for module 'CliUtils'
#
# Generated by: Blaise Mullenix
#
# Generated on: 11/15/2024
#

@{

# Script module or binary module file associated with this manifest.
RootModule = 'CliUtils'

# Version number of this module.
ModuleVersion = '1.0.7'

# Supported PSEditions
# CompatiblePSEditions = @()

# ID used to uniquely identify this module
GUID = '2a8bfe40-9137-4d57-9547-0667ae485901'

# Author of this module
Author = 'Blaise Mullenix'

# Company or vendor of this module
CompanyName = 'None'

# Copyright statement for this module
Copyright = '(c) Blaise Mullenix. All rights reserved.'

# Description of the functionality provided by this module
Description = 'Diverse functions to streamline commandline functions.'

# Minimum version of the PowerShell engine required by this module
PowerShellVersion = '5.1'

# Name of the PowerShell host required by this module
# PowerShellHostName = ''

# Minimum version of the PowerShell host required by this module
# PowerShellHostVersion = ''

# Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
# DotNetFrameworkVersion = ''

# Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
# ClrVersion = ''

# Processor architecture (None, X86, Amd64) required by this module
# ProcessorArchitecture = ''

# Modules that must be imported into the global environment prior to importing this module
# RequiredModules = @()

# Assemblies that must be loaded prior to importing this module
# RequiredAssemblies = @()

# Script files (.ps1) that are run in the caller's environment prior to importing this module.
ScriptsToProcess = 'enums/enums.ps1', 
               'classes/transformations/IfPathStringTransformToFileSystemInfo.ps1', 
               'classes/transformations/TransformToChmodGrant.ps1', 
               'classes/completions/GitBranchCompletions.ps1', 
               'classes/ItemSize.ps1', 'classes/newline.ps1', 
               'classes/SearchObject.ps1', 'classes/PSDirTree.ps1', 
               'public/Add-EnvironmentVariable.ps1', 'public/Back-Dir.ps1', 
               'public/Checkpoint-ModuleVersion.ps1', 
               'public/Compare-FileDiff.ps1', 'public/Convert-Base64.ps1', 
               'public/env.ps1', 'public/Find-FileRecursively.ps1', 
               'public/Find-StringRecursively.ps1', 'public/Get-Dir.ps1', 
               'public/Get-ItemSize.ps1', 'public/Get-ObjectLength.ps1', 
               'public/Get-ObjectType.ps1', 'public/Group-ObjectCount.ps1', 
               'public/Invoke-JoinOperator.ps1', 'public/Invoke-MatchOperator.ps1', 
               'public/Invoke-ReplaceOperator.ps1', 
               'public/Invoke-SplitOperator.ps1', 
               'public/Measure-CollectionCount.ps1', 'public/LockThread.ps1', 
               'public/Out-AllPropertiesInGridView.ps1', 'public/Out-FileHash.ps1', 
               'public/Repair-GitConflictsInFiles.ps1', 
               'public/Replace-StringInFile.ps1', 
               'public/Search-ObjectProperties.ps1', 
               'public/Search-ObjectValues.ps1', 'public/Select-NestedObject.ps1', 
               'public/Use-GitCliForBranch.ps1', 
               'public/Invoke-DefinitelyNotAfk.ps1'

# Type files (.ps1xml) to be loaded when importing this module
# TypesToProcess = @()

# Format files (.ps1xml) to be loaded when importing this module
FormatsToProcess = 'ps1xml/Find-StringRecursivelyViews.Format.ps1xml', 
               'ps1xml/ItemSizeViews.Format.ps1xml', 
               'ps1xml/Select-ObjectPropertiesViews.Format.ps1xml', 
               'ps1xml/PSDirTree.Format.ps1xml'

# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
# NestedModules = @()

# Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
FunctionsToExport = 'cd-', '..', '...', '....', '.....', '......', '.......', '........', '.........', 
               'Add-EnvironmentVariable', 'Back-Dir', 'Checkpoint-ModuleVersion', 
               'Compare-FileDiff', 'Convert-Base64', 'env', 'Find-FileRecursively', 
               'Find-StringRecursively', 'Get-Dir', 'Get-ItemSize', 'Get-ObjectLength', 
               'Get-ObjectType', 'Group-ObjectCount', 'Invoke-JoinOperator', 
               'Invoke-MatchOperator', 'Invoke-ReplaceOperator', 
               'Invoke-SplitOperator', 'Measure-CollectionCount', 'LockThread', 
               'Out-AllPropertiesInGridView', 'Out-FileHash', 
               'Repair-GitConflictsInFiles', 'Replace-StringInFile', 
               'Search-ObjectProperties', 'Search-ObjectValues', 
               'Select-NestedObject', 'Use-GitCliForBranch', 
               'Invoke-DefinitelyNotAfk'

# Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
CmdletsToExport = '*'

# Variables to export from this module
VariablesToExport = '*'

# Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
AliasesToExport = '*'

# DSC resources to export from this module
# DscResourcesToExport = @()

# List of all modules packaged with this module
# ModuleList = @()

# List of all files packaged with this module
# FileList = @()

# Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
PrivateData = @{

    PSData = @{

        # Tags applied to this module. These help with module discovery in online galleries.
        # Tags = @()

        # A URL to the license for this module.
        # LicenseUri = ''

        # A URL to the main website for this project.
        # ProjectUri = ''

        # A URL to an icon representing this module.
        # IconUri = ''

        # ReleaseNotes of this module
        # ReleaseNotes = ''

        # Prerelease string of this module
        # Prerelease = ''

        # Flag to indicate whether the module requires explicit user acceptance for install/update/save
        # RequireLicenseAcceptance = $false

        # External dependent modules of this module
        # ExternalModuleDependencies = @()

    } # End of PSData hashtable

} # End of PrivateData hashtable

# HelpInfo URI of this module
# HelpInfoURI = ''

# Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
# DefaultCommandPrefix = ''

}

