using namespace System.IO
Function Update-GcpProjectFS {
    $currentProjects = Import-CSV ([Gcp]::PathToProjectCSV) -Delimiter ','
    $currentFSProjects = Get-ChildItem ([Gcp]::ProjectRoot) -Recurse -File

    Write-Host "`nChecking for projects to housekeep..." -Fore Yellow
    Remove-GcpProjectHierarchyFromFSCache -GcpProjects $currentProjects -FilesystemProjects $currentFSProjects.Name

    $cleanedCurrentFSProjects = Get-ChildItem ([Gcp]::ProjectRoot) -Recurse -File
    Write-Host "`nUpdating local filesystem entries missing GKE cluster metadata with their metadata." -Fore Yellow
    Update-IncompleteGcpProjectsInFSCache -GcpProjects $currentProjects -FilesystemProjects $cleanedCurrentFSProjects

    Write-Host "`nAdding new projects to local filesystem cache" -Fore Yellow
    Add-MissingGcpProjectsToFSCache -GcpProjects $currentProjects -FilesystemProjects $cleanedCurrentFSProjects.Name

    Write-Host "`nFinished Updating local filesystem cache. See [Gcp]::ProjectRoot" -Fore Cyan
}

# This function will recursively climb up the parent folders and remove any that are empty. Stops climbing at [Gcp]::ProjectRoot.
Function Remove-GcpProjectHierarchyFromFSCache {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject[]]$GcpProjects,
        [string[]]$FilesystemProjects
    )
    $FilesystemProjects | Where-Object {
        $_ -notin $GcpProjects.Project_ID
    } | ForEach-Object {
        $projectToDelete = $_

        Write-Host "Project ID $projectToDelete no longer found in Gcp. Deleting project from local filesystem cache..." -Fore Red

        Get-ChildItem ([Gcp]::ProjectRoot) -Recurse -File -Filter $_ -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty FullName | 
            ForEach-Object {
                Remove-GcpProjectFromFSCacheRecursively -LocalFilePath $_ -RootPathEscapedRegex ([Regex]::Escape((Convert-Path ([Gcp]::ProjectRoot))))
            }

        Get-ChildItem "$([Gcp]::LocalCache)/pam-grants" -File | Where Name -match "_${projectToDelete}_" | Remove-Item
    }
}

Function Remove-GcpProjectFromFSCacheRecursively {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [string]$LocalFilePath,
        [Parameter(Mandatory)]
        [string]$RootPathEscapedRegex
    )
    Remove-Item -LiteralPath $LocalFilePath
    $parentDir = Split-Path $LocalFilePath -Parent

    # Perform 2 checks to determine if eligible for deletion:
        # 1) Remove the rootpath and see if there's any value leftover after trimming any . or dir separators.
            # This prevents the function from climbing up to or above the root path and deleting folders that should be kept.
        # 2) Check if the parent directory has empty contents.
            # This prevents the function from attempting to delete any directories that house other projects which still exist.
    if ( ($parentDir -replace $RootPathEscapedRegex).Trim('.' + [IO.Path]::DirectorySeparatorChar) -and
        -not (Get-ChildItem $parentDir)
    ) {
        Remove-GcpProjectFromFSCacheRecursively -LocalFilePath $parentDir -RootPathEscapedRegex $RootPathEscapedRegex
    }
}

Function Update-IncompleteGcpProjectsInFSCache {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject[]]$GcpProjects,
        [Parameter(Mandatory)]
        [FileInfo[]]$FilesystemProjects
    )
    #$oldProgressPreference = $ProgressPreference
    $ProgressPreference = 'Continue'
    [FileInfo[]]$projectsToUpdate = $FilesystemProjects | Where-Object {
        # If file already contains both name and location (count -eq 2), then no need to update it
        (Select-String -Pattern 'name|location' -Path $_.FullName).Matches.Count -ne 2 -and
        (Select-String -NotMatch 'Ineligible for GKE metadata' -Path $_.FullName) -and
        $_.Name -in $GcpProjects.PROJECT_ID -and
        (& ([Gcp]::ProjectHasGkeCluster) $_.Name)
    }
    $totalProjects = $projectsToUpdate.Count
    $count = -1
    $projectsToUpdate | Where-Object {$_} | ForEach-Object {
        Write-Progress -Activity 'Update-IncompleteGcpProjectsInFSCache' -Status $_.Name -PercentComplete (($count += 1) / $totalProjects)
        $localPath = $_.FullName
        try {
            $info = $_ | Get-GkeClusterMetaInfo -ErrorAction Stop
            if ( $info ) {
                Set-Content -Path $localPath -Value $info -Force
                Write-Host 'Updated missing meta information in filepath ' -Fore Cyan -NoNewLine; Write-Host $localPath
            } else {
                Set-Content -Path $localPath -Value 'Ineligible for GKE metadata' -Force
            }
        } catch {
            $_
        }
    }
    #$ProgressPreference = $oldProgressPreference
}

Function Add-MissingGcpProjectsToFSCache {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject[]]$GcpProjects,
        [PSCustomObject[]]$FilesystemProjects
    )
    $GcpProjects |
        Where-Object {
            $_.project_id -notin $FilesystemProjects -and
            $_.project_id -match ([Gcp]::FilterProjectIds) -and
            $_.name -match ([Gcp]::FilterProjectNames)            
        } |
        ForEach-Object {
            $projectId = $_.project_id
            Write-Host "Found new project folder $($_.name) ($($_.project_id)). Fetching metadata..." -Fore Green
            $projectDriveFilePath = Get-GcpProjectLineageAsFilepath -ProjectID $projectId

            if ( $projectDriveFilePath ) {

                Write-Host 'Adding new local filepath ' -Fore Magenta -NoNewLine; Write-Host $projectDriveFilePath
                $projectFullPath = Join-Path ([Gcp]::ProjectRoot) $projectDriveFilePath
                if ( & ([Gcp]::ProjectHasGkeCluster) $projectId ) {
                    try {
                        $gkeClusterMetaInfo = Get-GkeClusterMetaInfo -ProjectId $_.project_id -ErrorAction Stop
                        $null = New-Item -Path $projectFullPath -ItemType File -Value $gkeClusterMetaInfo -Force
                    } catch {
                        Write-Warning "Failed to get GKE metadata on project $projectId. Error: $($_ | Out-String)"
                        $null = New-Item -Path $projectFullPath -ItemType File -Force
                    }
                } else {
                    $null = New-Item -Path $projectFullPath -ItemType File -Force
                }

            }
            Write-Host '' # Add a space between logging outputs
        }
}

<# Notes on how the below function works
    For each project, there is a hierarchy of lineages obtained via gcloud get-ancestors. Each hierarchy is a folder in Gcp.
    We need to obtain their display names, i.e., folder names.
    For a single project id, the output of get-ancestors looks like this:
        ID                 TYPE
        --                 ----
        abc-0axk-rhji-v568 project
        387071328343       folder
        683520222268       folder
        0576461338171      folder
        862352227463       folder # Possible nested organization (still labeled here as folder by Gcp)
        385474470731       folder
        213350444167       organization
    We need to loop through each TYPE=folder and obtain the display name (folder name) via gcloud describe.
    If an organization number is defined in class [Gcp], we should stop at that ID number to avoid access errors on administrative tiers.
        This organization number is not necessarily TYPE=organization but could also be a folder as shown in the above example.
    At the end of the loop for a given project, join all the display names together. This is the folder path.
    The project ID comes from the describe of TYPE=type which outputs its parent (NOT given in the above hierarchy output) and the project ID.
        Therefore, the folder path must append the project parent and the project id. This is the "leaf" in the code above.
#>

Function Get-GcpProjectLineageAsFilepath {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [string]$GcpProjectId
    )
    $projectLineage = (gcloud projects get-ancestors $GcpProjectId) -replace
        '\s{2,}', [char]0x2561 |
        ConvertFrom-Csv -Delimiter ([char]0x2561)

    $folderNames = foreach ( $folder in ($projectLineage | where TYPE -eq folder) ){
        # Stop at the designated organization ID. This prevents permission errors for tiers above this.
        if ( $folder.ID -eq [Gcp]::OrganizationNumber ) {
            break
        }

        gcloud resource-manager folders describe $folder.ID --format json |
            ConvertFrom-Json |
            Select-Object -ExpandProperty DisplayName
    }
    if ( !$folderNames ) {
        return $null
    }
    [Array]::Reverse($folderNames) # reverse so the -join below in $childPath orders ascending to descending in the folder hierarchy.

    # Get the project type's display name and its parent's display name. These will be appended to the end of the final path.
    $projectID = $projectLineage | Where-Object type -eq 'project' | Select-Object -ExpandProperty id
    $ProjectLeafItem = gcloud projects describe $projectID --format json | ConvertFrom-Json

    # Express parent folders and leaf items as local filepaths
    $parentPath = $folderNames -join '/'

    # It is possible the project name can be the same as the parent folder, and in gcp this looks normal, but in the FS causes duplicates.
    $leafPath = if ( (Split-Path $parentpath -Leaf) -eq ($ProjectLeafItem.name) ) {
        $ProjectLeafItem.projectId
    } else {
        Join-Path $ProjectLeafItem.name $ProjectLeafItem.projectId
    }

    # Remove whitespace around hyphens to make later filesystem navigation more convenient.
    return (Join-Path $parentPath $leafPath) -replace '(?<=-)\s|\s(?=-)' -replace '\s', '-'
}

Function Get-GkeClusterMetaInfo {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName='projectId')]
        [string]$ProjectId,
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName='projectFileInfo')]
        [FileInfo]$ProjectFileInfo
    )

    process {
        $useProjectId = if ( $PSCmdlet.ParameterSetName -eq 'projectId' ) { $ProjectId } else { $ProjectFileInfo.Name }
        try {
            $gkeInfo = $useProjectId | Get-GkeClusterInfoFromProjectId
            $gkeInfo.ProjectId = $useProjectId
            $gkeInfo.ProjectNumber = (gcloud projects describe $useProjectId | Select-String projectNumber).Line.split(':')[1].Trim("' ")
            return ($gkeInfo.psobject.properties.name | ForEach-Object { "$_ = $($gkeInfo.$_)" }) -join "`n"
        } catch {
            if ($_.CategoryInfo.Category -eq 'ObjectNotFound') {
                Write-Debug $_
            }
            Write-Verbose "Cached project $useProjectId without GKE cluster metadata (e.g., no GKE cluster in this project)"
        }
    }
}

# Reproduced the function in this nested module so that it doesn't reimport the entire Gcputils module and overwrite my gcloud class's config.
function Get-GkeClusterInfoFromProjectId {
    [CmdletBinding()]
    [OutputType([GkeInfo])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$ProjectId
    )

    process {
        $checkIfCached = Get-ChildItem ([Gcp]::ProjectRoot) -File -Recurse | Where-Object Name -eq $ProjectId
        if ( (Select-String -Path ($checkIfCached) -Pattern '^Context') ) {
            return [PSCustomObject](Get-Content $checkIfCached -Raw | ConvertFrom-StringData)
        }

        $gkeClusterInfo = (gcloud container clusters list --project $ProjectId 2> $null) -replace '\s{2,}', [char]0x2561 | ConvertFrom-Csv -Delimiter ([char]0x2561)

        if ( ! $gkeClusterInfo.Name ) {
            $err = [System.Management.Automation.ErrorRecord]::new("Empty output from command: gcloud container clusters list --project $ProjectId", $null, 'ObjectNotFound', $null)
            $PSCmdlet.ThrowTerminatingError($err)
        }

        $gkeContext = "gke_${ProjectId}_$($gkeClusterInfo.Location)_$($gkeClusterInfo.Name)"
        $gkeClusterInfo | Add-Member -Name Context -Value $gkeContext -MemberType NoteProperty

        Write-Verbose "Cached $ProjectId with GKE cluster metadata"
        [GkeInfo]$gkeClusterInfo
    }
}