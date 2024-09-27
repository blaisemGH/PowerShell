using namespace System.IO
using namespace System.Text

function Sync-GCloudStandardGkeContextMappings {
    
    $currentMappings = Import-PowerShellDataFile -LiteralPath ([GCloud]::PathToProjectGkeMappings)
    $alreadyMappedProjectIds = $currentMappings.Values | foreach { $_ -split '_gke-' | Select-Object -last 1 }
    $currentProjectIds = Get-ChildItem -LiteralPath ([GCloud]::ProjectRoot) -Recurse -File |
        Select-Object -ExpandProperty Name
    
    $upToDateCurrentMappings = Get-GCloudStandardGkeMappingsUpToDate -CurrentGkeMappings $currentMappings -CurrentMappedProjectIds $alreadyMappedProjectIds
    $mappingsToCreate = $currentProjectIds | Where-Object { $_ -notin $alreadyMappedProjectIds -and $_ -notmatch ([GCloud]::PatternForNonGkeProjects) -and (& ([GCloud]::ProjectHasGkeCluster) $_) } | Sort-Object

    Write-Host "Creating mappings for $($mappingsToCreate.Count) projects."

    $mappingsToCreate |
        New-GCloudStandardGkeContextMapping |
        Sort-Object | 
        Export-GCloudStandardGkeContextMappings -ExistingMappingsToKeep ($upToDateCurrentMappings ?? @{})
    
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
            if ( (Get-Module KubectlUtils) ) {
                if ([Kube]::MappedContexts.Contains($mapping.Key)) {
                    continue
                }
            }
            $upToDateCurrentMappings.Add($mapping.Key, $mapping.Value)
        }
    }
    end {
        $upToDateCurrentMappings.GetEnumerator() | Sort-Object Key -Descending | foreach {
            $key, $value = ([string[]]$_.Key)[0], $_.Value
            $null = $fileStrings.AppendLine("`t'$key' = '$value'")
        }
        $null = $fileStrings.AppendLine('}')
        Write-Host "Exporting mappings:`n$($fileStrings.ToString())`n`n to file $([GCloud]::PathToProjectGkeMappings)" -Fore Magenta
        $fileStrings.ToString() | Set-Content -LiteralPath ([GCloud]::PathToProjectGkeMappings) -Force
    }
}
function New-GCloudStandardGkeContextMapping {
    param (
        [Parameter(Mandatory,ValueFromPipeline)]
        [string[]]$GcpProjectId
    )
    process {
        $gkeRelevantProjectIds = if ( [GCloud]::PatternForNonGkeProjects ) {
            $GcpProjectId | Where { $_ -notmatch ([GCloud]::PatternForNonGkeProjects) }
        }
        else {
            $GcpProjectId
        }

        foreach ( $projectId in $gkeRelevantProjectIds ) {
            if ( & ([GCloud]::ProjectHasGkeCluster) $projectId ) {
                Write-Host "Creating gke context mapping for project id: $projectId" -Fore Cyan
                
                try {
                    $localPath = Get-ChildItem ([GCloud]::ProjectRoot) -Recurse -File -Filter $projectID
                    $gkeClusterContext = if ( ($localPath | Select-String '^Context') ) {
                        Get-Content $localPath -Raw | ConvertFrom-StringData | Select-Object -ExpandProperty Context
                    } else {
                        $projectId | Get-GCloudGkeClusterInfoFromProjectId -ErrorAction Stop | Select-Object -ExpandProperty Context
                    }
                
                    $key = & ([GCloud]::NewGKEContextKey) $projectId

                    @{ $key = $gkeClusterContext }
                }
                catch {
                    Write-Host ($_.Exception.Message + " --> Cannot set a kube context mapping for this project, skipping it.")
                }
            }
        }
    }
}
