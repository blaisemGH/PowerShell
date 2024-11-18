function Set-GCloudConfigProject {
    param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [string]$ProjectId
    )
    end {
        # Find path to config file.
        $configFilesDir = Get-Content ([GCloud]::ConfigurationFileLocation)
        $configFiles = Get-ChildItem $configFilesDir -File -Filter 'config_*'
        
        # Prioritize config file using this $PID in case New-GCloudProjectSession has been invoked in this session.
        $useConfigFilepath = if ( $configFiles.Name -contains "config_$PID" ) {
            Join-Path $configFilesDir "config_$PID"
        } else {
            $configFiles |
                Where-Object { $_.Name -notmatch '^config_[0-9]+$' } |
                Sort-Object LastWriteTime |
                Select-Object -Last 1 -ExpandProperty FullName
        }

        # replace a call of [gcloud config set project $projectId] with a manual write to the file. This should save time. GCloud calls are so slow.
        (Get-Content $useConfigFilepath |
            ForEach-Object {
                $line = $_
                if ( $line -match '(?<=^project =\s*)(\S+)' -and $line -notmatch $ProjectId ) {
                    "project = $ProjectId"
                } else {
                    $line
                }
            }
        ) | Set-Content $useConfigFilePath -Force

        # Cache project in this module's GCloud session state
        [GCloud]::CurrentProject = $projectId
    }
}