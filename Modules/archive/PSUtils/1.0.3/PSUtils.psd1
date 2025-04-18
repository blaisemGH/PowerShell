#
# Module manifest for module 'PSUtils'
#
# Generated by: Blaise Mullenix
#
# Generated on: 2/4/2025
#

@{

# Script module or binary module file associated with this manifest.
RootModule = 'PSUtils.psm1'

# Version number of this module.
ModuleVersion = '1.0.3'

# Supported PSEditions
CompatiblePSEditions = 'Desktop', 'Core'

# ID used to uniquely identify this module
GUID = '07b72329-6191-408b-be58-378c61580d79'

# Author of this module
Author = 'Blaise Mullenix'

# Company or vendor of this module
CompanyName = 'None'

# Copyright statement for this module
Copyright = '(c) Blaise Mullenix. All rights reserved.'

# Description of the functionality provided by this module
Description = 'Utility functions for complex PowerShell tasks.'

# Minimum version of the PowerShell engine required by this module
PowerShellVersion = '7.3.6'

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
ScriptsToProcess = 'enums/MemoryUnits.ps1',
               'classes/ConvertToFullPathTransform.ps1', 'classes/MemoryUnitConverter.ps1',
               './public/Convert-AllHashtablesToPSCObjects.ps1', 
               './public/Convert-HashtableToOrderedDictionary.ps1', 
               './public/Convert-ObjectToHashtable.ps1', 
               './public/Join-ObjectLinq.ps1', './public/Test-ReadHost.ps1', 
               './public/Test-ValidArgs.ps1', 
               './public/Update-FileVersionIncrement.ps1', 
               './public/Sync-HeaderProperties.ps1', 
               './public/Move-FileToDatedFile.ps1', 'classes/ProcessHelper.ps1',
               './public/Convert-MemoryUnits.ps1', 'public/New-ErrorRecord.ps1'

# Type files (.ps1xml) to be loaded when importing this module
# TypesToProcess = @()

# Format files (.ps1xml) to be loaded when importing this module
# FormatsToProcess = @()

# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
# NestedModules = @()

# Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
FunctionsToExport = 'Convert-AllHashtablesToPSCObjects', 
               'Convert-HashtableToOrderedDictionary', 'Convert-ObjectToHashtable', 
               'Join-ObjectLinq', 'Test-ReadHost', 'Test-ContainsCollection', 
               'Update-FileVersionIncrement', 'Sync-HeaderProperties', 
               'Move-FileToDatedFile', 'Convert-MemoryUnits', 'New-ErrorRecord'

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
FileList = 'classes/ConvertToFullPathTransform.ps1', 
               './public/Convert-AllHashtablesToPSCObjects.ps1', 
               './public/Convert-HashtableToOrderedDictionary.ps1', 
               './public/Convert-ObjectToHashtable.ps1', 
               './public/Join-ObjectLinq.ps1', './public/Test-ReadHost.ps1', 
               './public/Test-ValidArgs.ps1', 
               './public/Update-FileVersionIncrement.ps1', 
               './public/Sync-HeaderProperties.ps1', 
               './public/Move-FileToDatedFile.ps1', 'classes/ProcessHelper.ps1'

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

