using namespace System.Text
function Remove-GCloudUnusedContexts {
    if ( Test-Path ([Kube]::ContextFile) ) {
        try {
            $getKubeContextMappings = Import-PowerShellDataFile ([Kube]::ContextFile)
        } catch { break }
    }
    $kubeContexts = $getKubeContextMappings.Values -split '_gke-' | Select-Object -Last 1
    $allUsedContexts = [Kube]::MappedContexts.Values -split '_gke-' | Select-Object -Last 1
    $existingProjectIds = Get-ChildItem -LiteralPath ([GCloud]::ProjectRoot) -Recurse -File |
        Select-Object -ExpandProperty Name

    $kubeContextsToRemove = if ( $existingProjectIds ) {
        $allUsedContexts | Where { $_ -in $kubeContexts -and $_ -notin $existingProjectIds }
    }

    if ( $kubeContextsToRemove ) {
        $stringBuilder = [StringBuilder]::new('@{')
        $getKubeContextMappings.GetEnumerator() | Sort-Object Keys -Descending | foreach {
            $key, $value, $projectId = $_.Key, $_.Value, ($_.Value -split '_gke-' | Select-Object -Last 1)
            if ( $projectId -notin $kubeContextsToRemove ) {
                $stringBuilder.AppendLine("$key = $value")
            }
        }
        $stringBuilder.AppendLine('}')
        $stringBuilder.ToString() | Set-Content -LiteralPath [kube]::ContextFile -Force
    }
}
