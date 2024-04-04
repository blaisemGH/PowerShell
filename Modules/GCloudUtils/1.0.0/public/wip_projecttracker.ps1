<#
gcloud projects get-ancestors rct-l2xb-xbc0-gvhj
gcloud resource-manager folders describe 1044266341655
gcloud resource-manager folders describe 619150277638
#>
$rootDir = 'C:\Users\MullenixJohn\.rcloud\projects'
$parent = 362699889522
$filterProjects = '^Space - '
#$filterRepetitiveStrings = 'Environment - |Space - |Tenants - '
<#
$p = (gcloud projects list) -replace '\s{2,}', [char]0x2561 | ConvertFrom-Csv -Delimiter ([char]0x2561)
$p | where name -match '^Space - '

$h = [collections.generic.list[object]]::new()
$p | where name -match '^Space - ' | % {
    $h.Add(((gcloud projects get-ancestors $_.project_id) -replace '\s{2,}', [char]0x2561 | ConvertFrom-Csv -Delimiter ([char]0x2561)))
}
#>

$h = [collections.generic.list[object]]::new()
$p | where name -match $filterProjects | % {
    $h.Add(((gcloud projects get-ancestors $_.project_id) -replace '\s{2,}', [char]0x2561 | ConvertFrom-Csv -Delimiter ([char]0x2561)))
}

foreach ( $f in $h) {
    $proj = gcloud projects describe ($f | where type -eq 'project' | select -exp id) --format json | ConvertFrom-Json

    $t = foreach ( $folder in ($f | where type -eq folder) ){
        if ( $folder.id -eq $parent) { break}
        gcloud resource-manager folders describe $folder.ID | ConvertFrom-StringData -Delimiter ':' | Where Keys -eq displayname | select -exp values
    }

    $childPath = ($t -join '/') + '/' + $proj.name + '/' + $proj.projectid
    $fullPath = join-path $rootDir $childPath
    New-Item $fullpath -ItemType File -force
}

Function Update-GCloudProjectList {
    (gcloud projects list) -replace
        '\s{2,}', [char]0x2561 |
            ConvertFrom-Csv -Delimiter ([char]0x2561) |
                Export-Csv -LiteralPath [GCloud]::PathToProjectCSV
}

Function Update-GCloudProjectFS {
    $currentProjects = Import-CSV [GCloud]::PathToProjectCSV

    $projectLineage = [collections.generic.list[PSCustomObject]]::new()
    
    # Iterate through each project and obtain its ancestor projects, e.g., higher-lying folders
    $currentProjects |
        Where-Object name -match $filterProjects |
        ForEach-Object {
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
        We need to loop through each folder, stopping at a nested organizationNumber if provided to avoid access errors on administrative tiers
        In each iteration, we run a describe to obtain the DisplayName.
        The folder path will join all these display names together. The leaf file is the display name of the project type and its parent.
    #>
    foreach ( $lineage in $projectLineage) {
    
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

        # Get the project type's display name and its parent's display name
        $leafProject = gcloud projects describe (
            $lineage | where type -eq 'project' | select -exp id
        ) --format json | ConvertFrom-Json
        
    
        # Set the display names as a filepath
        $childPath = ($displayNames -join '/') + '/' + $leafProject.name + '/' + $leafProject.projectId
        $fullPath = Join-Path [GCloud]::ProjectRoot $childPath
        New-Item $fullpath -ItemType File -force
    }

}