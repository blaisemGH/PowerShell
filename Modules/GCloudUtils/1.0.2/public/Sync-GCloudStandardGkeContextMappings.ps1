using namespace System.IO
using namespace System.Text

function Sync-GCloudStandardGkeContextMappings {
    
    $currentMappings = Import-PowerShellDataFile -LiteralPath ([GCloud]::PathToProjectGkeMappings)
    $alreadyMappedProjectIds = $currentMappings.Values | foreach { $_ -split '_gke-(?=r)' | Select-Object -last 1 }
    $currentProjectIds = Get-ChildItem -LiteralPath ([GCloud]::ProjectRoot) -Recurse -File |
        Select-Object -ExpandProperty Name
    
    $upToDateCurrentMappings = Get-GCloudStandardGkeMappingsUpToDate -CurrentGkeMappings $currentMappings -CurrentMappedProjectIds $alreadyMappedProjectIds
    $currentProjectIds |
        Where-Object { $_ -notin $alreadyMappedProjectIds } |
        New-GCloudStandardGkeContextMapping | Sort-Object 
        Export-GCloudStandardGkeContextMappings -ExistingMappingsToKeep $upToDateCurrentMappings
    
    Write-Host 'Done syncing all project IDs!' -ForegroundColor Cyan
}

function Get-GCloudStandardGkeMappingsUpToDate {
    param (
        [hashtable]$CurrentGkeMappings,
        [string[]]$CurrentMappedProjectIds
    )
    $currentMappings = if ( $CurrentGkeMappings ) { $CurrentGkeMappings } else { Import-PowerShellDataFile -LiteralPath ([GCloud]::PathToProjectGkeMappings) }
    $alreadyMappedProjectIds = if ( $CurrentMappedProjectIds ) { $CurrentMappedProjectIds } else { $currentMappings.Values | foreach { $_ -split '_gke-r' | Select-Object -last 1 } }

    # Removes mappings in the modular context file
    $removeOldMappings = $alreadyMappedProjectIds | Where-Object {$_ -notin $currentProjectIds } | foreach {
        $idToRemove = $_
        $currentMappings.GetEnumerator() |
            Where-Object { ($_.Value -split '_gke-r' | Select-Object -last 1) -eq  $idToRemove } |
            Select-Object -ExpandProperty Key
    }
    $null = $removeOldMappings | foreach { $currentMappings.Remove($_) }
    return $currentMappings
}

function Export-GCloudStandardGkeContextMappings {
    param (
        [Parameter(Mandatory,ValueFromPipeline)]
        [hashtable]$NewMapping,
        [hashtable]$ExistingMappingsToKeep
    )
    begin {
        $fileStrings = [StringBuilder]::new('@{').AppendLine()
        $upToDateCurrentMappings = & {
            if ( $ExistingMappingsToKeep ) {
                $ExistingMappingsToKeep
            }
            elseif ( $mappingsFromLocalFile = Get-GCloudStandardGkeMappingsUpToDate ) {
                $mappingsFromLocalFile
            }
            else {
                @{}
            }
        }
    }
    process {
        foreach ( $mapping in $NewMapping.GetEnumerator() ) {
            if ( [Kube]::MappedContexts.ContainsKey($mapping.Key) ) { continue }
            $upToDateCurrentMappings.Add($mapping.Key, $mapping.Value)
        }
    }
    end {
        $upToDateCurrentMappings.GetEnumerator() | Sort-Object Key -Descending | foreach {
            $key, $value = $_.Key, $_.Value
            $null = $fileStrings.AppendLine("`t'$key' = '$value'")
        }
        $null = $fileStrings.AppendLine('}')
        $fileStrings.ToString() | Set-Content -LiteralPath ([GCloud]::PathToProjectGkeMappings) -Force
    }
}
function New-GCloudStandardGkeContextMapping {
    param (
        [Parameter(Mandatory,ValueFromPipeline)]
        [string[]]$GcpProjectId
    )
    process {
        foreach ($projectId in ($GcpProjectId | Where { $_ -notmatch '-(metric-|aw-fallback|prod-(artifacts|backups|dns|secrets))'}) ) {
            $clusterGKEInfo = (gcloud container clusters list --project $projectId) -replace '\s{2,}', [char]0x2561 | ConvertFrom-Csv -Delimiter ([char]0x2561)
            if ($clusterGKEInfo) {
                $gkeContextString = 'gke_' + $projectId + '_' + $clusterGKEInfo.Location + '_gke-' + $projectId 

                $key = & ([GCloud]::NewGKEContextKey) $projectId

                @{ $key = $gkeContextString }
            }
        }
    }
}