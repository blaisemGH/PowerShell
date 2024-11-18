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
        # This step caches some information just to save calls to gcloud which cost seconds of time on session startup.
        # Cache the location of the configuration folder, so that a call to gcloud info --format='value(config.paths.global_config_dir)' is not necessary.
        if ( !(Test-Path ([GCloud]::ConfigurationFileLocation)) ) {
            New-Item ([GCloud]::ConfigurationFileLocation) -Force
        }

        # Refresh this config location once a day.
        $configFileLookup = Get-Item ([GCloud]::ConfigurationFileLocation)
        if ( $configFileLookup.LastWriteTime -lt (Get-Date).AddDays(-1) ) {
            [GCloud]::SetGCloudConfigurationLocation()
        }
        
        $configFilesDir = Get-Content ([GCloud]::ConfigurationFileLocation)
        $configFiles = Get-ChildItem $configFilesDir -File -Filter 'config_*'
        
        $useConfigFilepath = if ( $configFiles.Name -contains "config_$PID" ) {
            Join-Path $configFilesDir "config_$PID"
        } else {
            $configFiles |
                Where-Object { $_.Name -notmatch '^config_[0-9]+$' } |
                Sort-Object LastWriteTime |
                Select-Object -Last 1 -ExpandProperty FullName
        }

        return Get-Content $useConfigFilepath | 
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