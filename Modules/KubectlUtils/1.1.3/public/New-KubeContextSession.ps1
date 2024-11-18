function New-KubeContextSession {
    $sessionCacheDir = Join-Path ([Kube]::KubeLocalCache) sessions

    if ( !(Test-Path $sessionCacheDir) ) {
        New-Item $sessionCacheDir -ItemType Directory
    }
    
    $processName = Get-Process -PID $PID | Select-Object -ExpandProperty ProcessName
    $allProcessPIDs = Get-Process -Name $processName | Select-Object -ExpandProperty Id

    Get-ChildItem $sessionCacheDir | Where-Object { $_.Name.Split('_')[0] -notin $allProcessPIDs } | Remove-Item

    $kubeConfigPath = if ( $env:KUBECONFIG ) { $env:KUBECONFIG } else { "$HOME/.kube/config" }
    $newKubeConfigPath = Join-Path $sessionCacheDir "${PID}_config"

    Copy-Item -LiteralPath $kubeConfigPath -Destination $newKubeConfigPath -Force -ErrorAction Stop
    $env:KUBECONFIG = $newKubeConfigPath
}