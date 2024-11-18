function New-GCloudProjectSession {
    $processName = Get-Process -PID $PID | Select-Object -ExpandProperty ProcessName
    $allProcessPIDs = Get-Process -Name $processName | Select-Object -ExpandProperty Id

    $currentGcloudConfig = gcloud config configurations list --format=json | 
        ConvertFrom-Json | 
        Where-Object is_active -eq True | 
        Select-Object -ExpandProperty name
    
    $gcloudConfigRoot = gcloud info --format='value(config.paths.global_config_dir)'
    $currentGcloudConfig = Get-ChildItem $gcloudConfigRoot -Recurse -File -Filter "config_$currentGcloudConfig"
    $gcloudConfigDir = $currentGcloudConfig.Directory
    
    Get-ChildItem $gcloudConfigDir -File | Where-Object { $_.Name.Split('_')[-1] -notin $allProcessPIDs -and $_.Name -match '^config_[0-9]+$' } | Remove-Item
    
    $newGcloudConfigPath = Join-Path $gcloudConfigDir "config_$PID"

    if ( !$currentGcloudConfig ) {
        Throw "Did not find config $currentGcloudConfig via 'Get-ChildItem $gcloudConfigRoot -Recurse -File -Filter ""config_$currentGcloudConfig""'"
    }

    Copy-Item -LiteralPath $currentGcloudConfig -Destination $newGcloudConfigPath -Force -ErrorAction Stop
    $env:CLOUDSDK_ACTIVE_CONFIG_NAME = $PID
}