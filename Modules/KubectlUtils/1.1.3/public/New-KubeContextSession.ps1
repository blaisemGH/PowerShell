function New-KubeContextSession {
    # Local directory to cache forked configs for a given session.
    $sessionCacheDir = Join-Path ([Kube]::KubeLocalCache) sessions

    if ( !(Test-Path $sessionCacheDir) ) {
        New-Item $sessionCacheDir -ItemType Directory
    }
    
    # Getting powershell process name (could be windows powershell or pwsh), then all the PIDs of any running sessions.
    $processName = Get-Process -PID $PID | Select-Object -ExpandProperty ProcessName
    $allProcessPIDs = Get-Process -Name $processName | Select-Object -ExpandProperty Id

    # Housekeep any old forked sessions
    Get-ChildItem $sessionCacheDir | Where-Object { $_.Name.Split('_')[0] -notin $allProcessPIDs } #| Remove-Item

    # Get the current kube config path and define the new forked one.
    $kubeConfigPath = if ( $env:KUBECONFIG ) { $env:KUBECONFIG } else { "$HOME/.kube/config" }
    $newKubeConfigPath = Join-Path $sessionCacheDir "${PID}_config"

    Copy-Item -LiteralPath $kubeConfigPath -Destination $newKubeConfigPath -Force -ErrorAction Stop
    Write-Verbose "Forked kube config to $newKubeConfigPath"
    
    $env:KUBECONFIG = $newKubeConfigPath
    Write-Verbose "set `$env:KUBECONFIG to $newKubeConfigPath"
    
    [Kube]::IsConfigForked = $true
}