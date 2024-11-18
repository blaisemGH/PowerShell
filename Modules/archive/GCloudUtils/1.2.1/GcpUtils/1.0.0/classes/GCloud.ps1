Class GCloud {
    static [string]$LocalCache = "$HOME/.pwsh/gcloud/"
    static [string]$PathToProjectCSV = ( Join-Path ([GCloud]::LocalCache) projects.csv )
    static [string]$PathToProjectGkeMappings = ( Join-Path ([GCloud]::LocalCache) gcloudContexts.psd1 )
    static [string]$ProjectRoot = ( Join-Path ([GCloud]::LocalCache) projects )
    static [string]$ConfigurationFileLocation = (Join-Path ([GCloud]::LocalCache) gcloudConfigFilePath.txt)
    static [string]$OrganizationNumber = ''
    static [string]$FilterProjectIds = '.*'
    static [string]$FilterProjectNames = '.*'
    static [string]$PatternForNonGkeProjects
    static [hashtable]$CompletionTree
    static [int]$MinimumSyncFrequency
    static [hashtable]$Config
    static [scriptblock]$ProjectHasGkeCluster = { $true }
    static [scriptblock]$NewGKEContextKey = {
        param(
            [Parameter(Mandatory)]
            $ProjectLocalFilepath
        )
        return (Get-ChildItem ([GCloud]::ProjectRoot) -Recurse -File -Filter $ProjectLocalFilepath).FullName -replace '/','-'
    }

    static [string]$CurrentProject = ( & {
        if ( !(Test-Path ([GCloud]::ConfigurationFileLocation)) ) {
            New-Item ([GCloud]::ConfigurationFileLocation) -Force
        }
        $configFileLookup = Get-Item ([GCloud]::ConfigurationFileLocation)
        if ( $configFileLookup.LastWriteTime -lt (Get-Date).AddDays(-1) ) {
            [GCloud]::SetGCloudConfigurationLocation()
        }
        
        return Get-Content ([GCloud]::ConfigurationFileLocation) |
            Get-ChildItem -Filter 'config_*' |
            Sort-Object LastWriteTime |
            Select-Object -Last 1 |
            Get-Content |
            Select-String '(?<=^project =\s*)(\S+)' | Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Value
    })

    static [string] GetGCloudConfigDirectory() {
        $activeConfigFilePath = (gcloud info | Select-String '^active configuration path') -Split ':\s*' | Select-Object -Last 1
        return Get-Item ($activeConfigFilePath.Trim(' []')) | Select-Object -ExpandProperty DirectoryName
    }
    static [void] SetGCloudConfigurationLocation() {
        [GCloud]::GetGCloudConfigDirectory() | Set-Content -Path ([GCloud]::ConfigurationFileLocation)
    }

    static [void] SetGCloudProperties ([hashtable]$propertiesToSet) {
        [GCloud]::Config = $propertiesToSet
        $propertiesToSet.GetEnumerator() | ForEach-Object {
            [GCloud]::$($_.Key) = $_.Value
        }
    }
}