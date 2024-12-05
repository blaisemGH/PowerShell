function New-GCloudProjectSession {
    # Getting powershell process name (could be windows powershell or pwsh), then all the PIDs of any running sessions.
    $processName = Get-Process -PID $PID | Select-Object -ExpandProperty ProcessName
    $allProcessPIDs = Get-Process -Name $processName | Select-Object -ExpandProperty Id

    # Name of current active GCloud config. We have to use this as the basis for the forked config.
    $currentGcloudConfig = gcloud config configurations list --format=json | 
        ConvertFrom-Json | 
        Where-Object is_active -eq True | 
        Select-Object -ExpandProperty name

    # Get current gcloud config file and its directory
    $gcloudConfigRoot = gcloud info --format='value(config.paths.global_config_dir)'
    $currentGcloudConfig = Get-ChildItem $gcloudConfigRoot -Recurse -File -Filter "config_$currentGcloudConfig"
    $gcloudConfigDir = $currentGcloudConfig.Directory
    
    # Housekeep old forked gcloud config sessions
    Get-ChildItem $gcloudConfigDir -File | Where-Object { $_.Name.Split('_')[-1] -notin $allProcessPIDs -and $_.Name -match '^config_[0-9]+$' } | Remove-Item
    
    $newGcloudConfigPath = Join-Path $gcloudConfigDir "config_$PID"

    if ( !$currentGcloudConfig ) {
        Throw "Did not find config $currentGcloudConfig via 'Get-ChildItem $gcloudConfigRoot -Recurse -File -Filter ""config_$currentGcloudConfig""'"
    }

    Copy-Item -LiteralPath $currentGcloudConfig -Destination $newGcloudConfigPath -Force -ErrorAction Stop
    Write-Verbose "Forked config to $newGcloudConfigPath"
    
    $env:CLOUDSDK_ACTIVE_CONFIG_NAME = $PID
    Write-Verbose "Set `$env:CLOUDSDK_ACTIVE_CONFIG_NAME to $PID"
}