using namespace System.Text
<#function Remove-GCloudUnusedContexts {
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
#>

Function Remove-GCloudUnusedGkeContexts {
        
    Write-Verbose 'Performing housekeeping to remove nonexistent contexts.' -Fore Magenta
    $currentProjects = Get-ChildItem -LiteralPath ([GCloud]::ProjectRoot) -Recurse -File | Select-Object -ExpandProperty Name
    $kubeContexts = kubectl config get-contexts -o name
    $customMappedContexts = Import-PowerShellDataFile ([Kube]::ContextFile) | Select-Object -ExpandProperty Values
    $standardMappedContexts = Import-PowerShellDataFile ([GCloud]::PathToProjectGkeMappings) | Select-Object -ExpandProperty Values
    $contextsToRemove = $kubeContexts + $customMappedContexts + $standardMappedContexts |
        Sort-Object -Unique |
            Where {
                $_ -match '^gke(_[-a-z0-9]+){2}_gke-[-0-9a-z]+$' -and
                ($_ | Rename-GCloudGkeContextToProjectId) -notin $currentProjects
            }
    if ( $contextsToRemove ) {
        Write-Verbose "Removing the following contexts for housekeeping: `n`n$( $contextsToRemove | Out-String )"
        Remove-KubeMappedContext -PatternsToRemove $contextsToRemove -PSDataFilePath ([Kube]::ContextFile)
        Remove-KubeMappedContext -PatternsToRemove $contextsToRemove -PSDataFilePath ([GCloud]::PathToProjectGkeMappings)
    }
    else {
        Write-Verbose "Housekeeping found no unused contexts to remove!"
    }
}