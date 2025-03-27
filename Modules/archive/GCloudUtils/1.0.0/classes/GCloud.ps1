Class GCloud {
    static [string]$PathToProjectCSV = "$HOME/.pwsh/gcloud/projects.csv"
    static [string]$ProjectRoot = "$HOME/.pwsh/gcloud/projects"
    static [string]$OrganizationNumber = ''
    static [string]$FilterProjects = '.*'

    static [void] Set_GCloudProperties ([hashtable]$propertiesToSet) {
        $propertiesToSet.GetEnumerator() | ForEach-Object {
            [GCloud]::$_.Key = $_.Value
        }
    }
}