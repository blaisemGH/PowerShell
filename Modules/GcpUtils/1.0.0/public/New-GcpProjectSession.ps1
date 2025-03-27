function New-GcpProjectSession {
    # Getting powershell process name (could be windows powershell or pwsh), then all the PIDs of any running sessions.
    $processName = Get-Process -PID $PID | Select-Object -ExpandProperty ProcessName
    $allProcessPIDs = Get-Process -Name $processName | Select-Object -ExpandProperty Id

    # Name of current active GCloud config. We have to use this as the basis for the forked config.
    $currentGcpConfig = gcloud config configurations list --format=json | 
        ConvertFrom-Json | 
        Where-Object is_active -eq True | 
        Select-Object -ExpandProperty name

    # Get current gcloud config file and its directory
    $GcpConfigRoot = gcloud info --format='value(config.paths.global_config_dir)'
    $currentGcpConfig = Get-ChildItem $GcpConfigRoot -Recurse -File -Filter "config_$currentGcpConfig"
    $GcpConfigDir = $currentGcpConfig.Directory
    
    # Housekeep old forked gcloud config sessions
    Get-ChildItem $GcpConfigDir -File | Where-Object { $_.Name.Split('_')[-1] -notin $allProcessPIDs -and $_.Name -match '^config_[0-9]+$' } | Remove-Item
    
    $newGcpConfigPath = Join-Path $GcpConfigDir "config_$PID"

    if ( !$currentGcpConfig ) {
        Throw "Did not find config $currentGcpConfig via 'Get-ChildItem $GcpConfigRoot -Recurse -File -Filter ""config_$currentGcpConfig""'"
    }

    Copy-Item -LiteralPath $currentGcpConfig -Destination $newGcpConfigPath -Force -ErrorAction Stop
    Write-Verbose "Forked config to $newGcpConfigPath"
    
    $env:CLOUDSDK_ACTIVE_CONFIG_NAME = $PID
    Write-Verbose "Set `$env:CLOUDSDK_ACTIVE_CONFIG_NAME to $PID"
}