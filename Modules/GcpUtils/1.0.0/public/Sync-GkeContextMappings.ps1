using namespace System.IO
using namespace System.Text

function Sync-GkeContextMappings {
    [CmdletBinding()]
    param()
    Write-Host "`nBeginning to write standardized mappings for Gke contexts. This may take a while." -Fore Yellow

    $currentMappings = Import-PowerShellDataFile -LiteralPath ([Gcp]::PathToProjectGkeMappings)
    $alreadyMappedProjectIds = $currentMappings.Values | foreach { $_ -split '_gke-' | Select-Object -last 1 }
    $currentProjectIds = Get-ChildItem -LiteralPath ([Gcp]::ProjectRoot) -Recurse -File |
        Select-Object -ExpandProperty Name

    $upToDateCurrentMappings = Get-GcpStandardGkeMappingsUpToDate -CurrentGkeMappings $currentMappings -CurrentMappedProjectIds $alreadyMappedProjectIds
    $mappingsToCreate = $currentProjectIds | Where-Object { $_ -notin $alreadyMappedProjectIds -and $_ -notmatch ([Gcp]::PatternForNonGkeProjects) -and (& ([Gcp]::ProjectHasGkeCluster) $_) } | Sort-Object

    Write-Host "Creating mappings for $($mappingsToCreate.Count) projects."

    $mappingsToCreate |
        New-GcpStandardGkeContextMapping |
        Sort-Object | 
        Export-GcpStandardGkeContextMappings -ExistingMappingsToKeep ($upToDateCurrentMappings ?? @{})

    Write-Host 'Done syncing all project IDs!' -ForegroundColor Cyan
}

function Get-GcpStandardGkeMappingsUpToDate {
    [CmdletBinding()]
    param (
        [hashtable]$CurrentGkeMappings,
        [string[]]$CurrentMappedProjectIds
    )
    $currentMappings = if ( $CurrentGkeMappings ) { $CurrentGkeMappings } else { Import-PowerShellDataFile -LiteralPath ([Gcp]::PathToProjectGkeMappings) }
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

function Export-GcpStandardGkeContextMappings {
    [CmdletBinding()]
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
            elseif ( $mappingsFromLocalFile = Get-GcpStandardGkeMappingsUpToDate ) {
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
        Write-Host "Exporting mappings:`n$($fileStrings.ToString())`n`n to file $([Gcp]::PathToProjectGkeMappings)" -Fore Magenta
        $fileStrings.ToString() | Set-Content -LiteralPath ([Gcp]::PathToProjectGkeMappings) -Force
    }
}
function New-GcpStandardGkeContextMapping {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,ValueFromPipeline)]
        [string[]]$GcpProjectId
    )
    process {
        $gkeRelevantProjectIds = if ( [Gcp]::PatternForNonGkeProjects ) {
            $GcpProjectId | Where { $_ -notmatch ([Gcp]::PatternForNonGkeProjects) }
        }
        else {
            $GcpProjectId
        }

        foreach ( $projectId in $gkeRelevantProjectIds ) {
            if ( & ([Gcp]::ProjectHasGkeCluster) $projectId ) {
                Write-Host "Creating gke context mapping for project id: $projectId" -Fore Cyan

                try {
                    $localPath = Get-ChildItem ([Gcp]::ProjectRoot) -Recurse -File -Filter $projectID | Sort-Object LastWriteTime | Select -Last 1
                    $gkeClusterContext = if ( ($localPath | Select-String '^Context') ) {
                        Get-Content $localPath -Raw | ConvertFrom-StringData | Select-Object -ExpandProperty Context
                    } else {
                        $projectId | Get-GkeClusterInfoFromProjectId -ErrorAction Stop | Select-Object -ExpandProperty Context
                    }

                    $key = & ([Gcp]::NewGKEContextKey) $projectId

                    @{ $key = $gkeClusterContext }
                }
                catch {
                    Write-Host ($_.Exception.Message + " --> Cannot set a kube context mapping for this project, e.g., project is in deletion. Skipping this project.)")
                }
            }
        }
    }
}