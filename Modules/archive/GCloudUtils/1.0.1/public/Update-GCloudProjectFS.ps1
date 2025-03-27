Function Update-GCloudProjectFS {
    $currentProjects = Import-CSV ([GCloud]::PathToProjectCSV) -Delimiter ','
    $currentFSProjects = Get-ChildItem ([GCloud]::ProjectRoot) -Recurse -File | Select-Object -ExpandProperty Name

    # Remove projects that no longer exist. Will recursively climb up the parent folders and remove any that are empty. Stops climbing at [GCloud]::ProjectRoot.
    $currentFSProjects | Where-Object {
        $_ -notin $currentProjects.Project_ID
    } | ForEach-Object {
        Write-Host "Project ID $_ no longer found in GCloud. Deleting local entry..." -Fore Red
        Get-ChildItem ([GCloud]::ProjectRoot) -Recurse -File -Name -Filter $_ | ForEach-Object {
            Remove-OldProject $_
        }
    }

    $projectLineage = [collections.generic.list[PSCustomObject]]::new()

    # Iterate through each project and obtain its ancestor projects, e.g., higher-lying folders
    $currentProjects |
        Where-Object {
            $_.name -match ([GCloud]::FilterProjects) -and
            $_.project_id -notin $currentFSProjects
        } |
        ForEach-Object {
            Write-Host "Found new project folder $($_.name). Getting ancestors..." -Fore Green
            $projectLineage.Add((
                (gcloud projects get-ancestors $_.project_id) -replace
                    '\s{2,}', [char]0x2561 |
                    ConvertFrom-Csv -Delimiter ([char]0x2561)
            ))
        }

    <# For each project lineage, loop through each tier in the lineage hierarchy and obtain their display names
        The lineages look something like this:
            ID                 TYPE
            --                 ----
            abc-0axk-rhji-v568 project
            387071328343       folder
            683520222268       folder
            0576461338171      folder
            862352227463       folder # Possible nested organization (still labeled here as folder by GCloud)
            385474470731       folder
            213350444167       organization
        We need to loop through each folder, stopping at a nested organizationNumber (if defined in [GCloud]) to avoid access errors on administrative tiers.
        In each iteration, we run a describe to obtain the DisplayName.
        The folder path will join all these display names together. The leaf file is the display name of the project type and its parent.
    #>
    foreach ( $lineage in $projectLineage) {
        # Get the project type's display name and its parent's display name. These will be appended to the end of the final path.
        $leafProject = gcloud projects describe (
            $lineage | where type -eq 'project' | select -exp id
        ) --format json | ConvertFrom-Json
        
        Write-Host "Parsing the lineage of new project $($leafProject.name)/$($leafProject.projectId)" -Fore Cyan
        $displayNames = foreach ( $folder in ($lineage | where TYPE -eq folder) ){
            # Stop at the designated organization ID. This prevents permission errors for tiers above this.        
            if ( $folder.ID -eq [GCloud]::OrganizationNumber ) { 
                break
            }

            gcloud resource-manager folders describe $folder.ID | 
                ConvertFrom-StringData -Delimiter ':' | 
                Where-Object Keys -eq displayname |
                Select-Object -ExpandProperty values
        }
        [Array]::Reverse($displayNames) # reverse so the -join below in $childPath orders ascending to descending in the folder hierarchy.

        # Set the display names as a filepath
        $childPath = ($displayNames -join '/') + '/' + $leafProject.name + '/' + $leafProject.projectId
        $fullPath = Join-Path ([GCloud]::ProjectRoot) ($childPath -replace '(?<=-)\s|\s(?=-)' -replace '\s', '-')
        Write-Host 'Adding new local path ' -Fore Magenta; Write-Host $fullPath -NoNewLine
        $null = New-Item $fullpath -ItemType File -force
    }

}

Function Remove-OldProject {
    Param(
        [Parameter(Mandatory)]
        [string]$ProjectFSPath
    )
    Remove-Item -LiteralPath $ProjectFSPath
    $parent = Split-Path $ProjectFSPath -Parent
    if ( (Test-Path ($parent -replace ([GCloud]::ProjectRoot) ) -and ! (Get-ChildItem $parent) ) ) {
        Remove-OldProject $parent
    }
}