using namespace System.IO
function Set-GcpConfigProject {
    param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [string]$ProjectId
    )
    end {
        # Find path to config file.
        $configFilesDir = Get-Content ([Gcp]::ConfigurationFileLocation)
        $configFiles = Get-ChildItem $configFilesDir -File -Filter 'config_*'

        # Prioritize config file using this $PID in case New-GcpProjectSession has been invoked in this session.
        $useConfigFilepath = if ( $configFiles.Name -contains "config_$PID" ) {
            Join-Path $configFilesDir "config_$PID"
        } else {
            $configFiles |
                Where-Object { $_.Name -notmatch '^config_[0-9]+$' } |
                Sort-Object LastWriteTime |
                Select-Object -Last 1 -ExpandProperty FullName
        }

        # Check if file is unlocked and wait if true
        while ($(
            try { [IO.File]::OpenWrite($useConfigFilepath).close();$false }
            catch [IOException] {$true}
        )) {
            Start-Sleep -MilliSeconds 200
        }
        # Update gcloud config file. This avoids `gcloud config set project` as gcloud calls can take several hundred milliseconds.
        try {
            # Net methods used instead of pwsh cmdlets to encapsulate the entire read/write process within a file lock
            $configFileLock = [File]::Open($useConfigFilepath, [FileMode]::Open, [FileAccess]::ReadWrite, [FileShare]::Read)
            $reader = [StreamReader]::new($configFileLock)

            $currentFileContent = $reader.ReadToEnd()
            $reader.Close()
            $newFileContent = $currentFileContent -replace '(?sm)(?<=^project =\s*)(\S+)', $ProjectId

            $tempFile = New-TemporaryFile
            $writer = [StreamWriter]::new($tempFile)
            $writer.Write($newFileContent)
            $writer.Close()

            $configFileLock.Close()
            [File]::Move($tempFile, $useConfigFilepath, $true)
        } catch [IOException] {
            Write-Error $_
        } finally {
            $writer.Close()
            $reader.Close()
            $configFileLock.Close()
        }

        # Previous pwsh implementation. I did not like that the write wasn't part of the file lock, plus I don't think Get-Content shares read access, which would be important as gcloud can frequently want to read its own config.
        # replace a call of [gcloud config set project $projectId] with a manual write to the file. This should save time. GCloud calls are so slow.
        <#try {
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
        } catch [IOException] {} # ignore concurrent file access exception
#>
        if ( !(Select-String -Path $useConfigFilePath -Pattern "^project\s*=\s*$ProjectId" ) ){
            gcloud config set project $ProjectId
        }

        # Cache project in this module's GCloud session state
        [Gcp]::CurrentProject = $ProjectId
    }
}