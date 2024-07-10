#
# Module manifest for module 'KubeCtlUtils'
#
# Generated by: Blaise Mullenix
#
# Generated on: 5/30/2024
#

@{

# Script module or binary module file associated with this manifest.
RootModule = 'KubectlUtils'

# Version number of this module.
ModuleVersion = '1.1.0'

# Supported PSEditions
CompatiblePSEditions = 'Desktop', 'Core'

# ID used to uniquely identify this module
GUID = '5b3ad961-9bf4-4f35-8d08-6798e39dea82'

# Author of this module
Author = 'Blaise Mullenix'

# Company or vendor of this module
CompanyName = 'None'

# Copyright statement for this module
Copyright = '(c) Blaise Mullenix. All rights reserved.'

# Description of the functionality provided by this module
Description = 'Utility functions that wrap kubectl functionality'

# Minimum version of the PowerShell engine required by this module
PowerShellVersion = '7.2.1'

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
RequiredModules = @('PSUtils')

# Assemblies that must be loaded prior to importing this module
# RequiredAssemblies = @()

# Script files (.ps1) that are run in the caller's environment prior to importing this module.
ScriptsToProcess = 'classes\kube.ps1', 'classes/completions/KubeMappedContextCompleter.ps1', 'classes\KubeNodesByPod.ps1', 
               'private\Measure-KubeContainers.ps1', 'public\Copy-KubeFile.ps1', 
               'public\Enter-KubePod.ps1', 'public\Find-MaxPodMetric.ps1', 
               'public\Get-KubeContextInfo.ps1', 'public\Get-KubeMetrics.ps1', 
               'public\Get-KubeNodesByPod.ps1', 'public\Get-KubeResource.ps1', 
               'public\Measure-DiskIO.ps1', 'public\Set-KubeContext.ps1', 
               'public\Set-KubeNamespace.ps1', 'public\Trace-KubeMetrics.ps1', 
               'public\Update-KubeCompletions.ps1', 'public\Remove-KubeContextsIfUnused.ps1', 
               'public\ConvertFrom-StringTable.ps1', 'public/Get-KubeMappedContext',
               'public/Remove-KubeMappedContext', 'public/Rename-KubeMappedContext',
               'public/Set-KubeMappedContexts'

# Type files (.ps1xml) to be loaded when importing this module
# TypesToProcess = @()

# Format files (.ps1xml) to be loaded when importing this module
FormatsToProcess = 'ps1xml/KubeMetricsViews.Format.ps1xml', 
               'ps1xml/KubeNodesByPodViews.Format.ps1xml', 
               'ps1xml/KubeMaxPodMetricsViews.Format.ps1xml'

# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
# NestedModules = @()

# Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
FunctionsToExport = 'Measure-KubeContainers', 'Copy-KubeFile', 'Enter-KubePod', 
               'Find-MaxPodMetric', 'Get-KubeContextInfo', 'Get-AllKubeMetrics', 
               'Get-KubeMetrics', 'Get-KubeNodesByPod', 'Get-KubeResource', 
               'Measure-DiskIO', 'Set-KubeContext', 'Set-KubeNamespace', 
               'Trace-KubeMetrics', 'Update-KubeCompletions', 
               'ConvertFrom-StringTable', 'Remove-KubeContextsIfUnused',
               'Get-KubeMappedContext', 'Remove-KubeMappedContext',
               'Rename-KubeMappedContext', 'Set-KubeMappedContexts'

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
FileList = 'classes\kube.ps1', 'classes\KubeNodesByPod.ps1', 'KubectlUtils.psm1', 
               'private\Measure-KubeContainers.ps1', 'public\Copy-KubeFile.ps1', 
               'public\Enter-KubePod.ps1', 'public\Find-MaxPodMetric.ps1', 
               'public\Get-KubeContext.ps1', 'public\Get-KubeMetrics.ps1', 
               'public\Get-KubeNodesByPod.ps1', 'public\Get-KubeResource.ps1', 
               'public\Measure-DiskIO.ps1', 'public\Set-KubeContext.ps1', 
               'public\Set-KubeNamespace.ps1', 'public\Trace-KubeMetrics.ps1', 
               'public\Update-KubeCompletions.ps1', 
               'public\ConvertFrom-StringTable.ps1'

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

