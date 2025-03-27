Class Gcp {
    static [string]$LocalCache = "$HOME/.pwsh/gcp/"
    static [string]$PathToProjectCSV = ( Join-Path ([Gcp]::LocalCache) projects.csv )
    static [string]$PathToProjectGkeMappings = ( Join-Path ([Gcp]::LocalCache) GcpContexts.psd1 )
    static [string]$ProjectRoot = ( Join-Path ([Gcp]::LocalCache) projects )
    static [string]$ConfigurationFileLocation = (Join-Path ([Gcp]::LocalCache) gcloudConfigFilePath.txt)
    static [string]$OrganizationNumber = ''
    static [string]$FilterProjectIds = '.*'
    static [string]$FilterProjectNames = '.*'
    static [string]$PatternForNonGkeProjects
    static [scriptblock]$SyncProjectsPreparatoryFunction
    static [int]$MinimumSyncFrequency
    static [hashtable]$Config
    static [scriptblock]$ProjectHasGkeCluster = { $true }
    static [scriptblock]$NewGKEContextKey = {
        param(
            [Parameter(Mandatory)]
            $ProjectLocalFilepath
        )
        return (Get-ChildItem ([Gcp]::ProjectRoot) -Recurse -File -Filter $ProjectLocalFilepath).FullName -replace '/','-'
    }

    static [string]$CurrentProject = ( & {
        # This step caches some information just to save calls to gcloud which cost seconds of time on session startup.
        # Cache the location of the configuration folder, so that a call to gcloud info --format='value(config.paths.global_config_dir)' is not necessary.
        if ( !(Test-Path ([Gcp]::ConfigurationFileLocation)) ) {
            New-Item ([Gcp]::ConfigurationFileLocation) -Force
        }

        # Refresh this config location once a day.
        $configFileLookup = Get-Item ([Gcp]::ConfigurationFileLocation)
        if ( $configFileLookup.LastWriteTime -lt (Get-Date).AddDays(-1)  -or !(Get-Content ([Gcp]::ConfigurationFileLocation)) ) {
            [Gcp]::SetGcpConfigurationLocationFile()
        }

        $configFilesDir = Get-Content ([Gcp]::ConfigurationFileLocation)
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

    static [string] GetGcpConfigDirectory() {
        $activeConfigFilePath = (gcloud info | Select-String '^active configuration path') -Split ':\s+' | Select-Object -Last 1
        return Get-Item ($activeConfigFilePath.Trim(' []')) | Select-Object -ExpandProperty DirectoryName
    }
    static [void] SetGcpConfigurationLocationFile() {
        [Gcp]::GetGcpConfigDirectory() | Set-Content -Path ([Gcp]::ConfigurationFileLocation)
    }

    static [void] SetGcpProperties ([hashtable]$propertiesToSet) {
        [Gcp]::Config = $propertiesToSet
        $propertiesToSet.GetEnumerator() | ForEach-Object {
            [Gcp]::$($_.Key) = $_.Value
        }
    }

}