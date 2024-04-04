Class GCloud {
    static [string]$PathToProjectCSV = "$HOME/.pwsh/gcloud/projects.csv"
    static [string]$ProjectRoot = "$HOME/.pwsh/gcloud/projects"
    static [string]$OrganizationNumber = ''
    static [string]$FilterProjectIds = '.*'
    static [string]$FilterProjectNames = '.*'
    static [int]$MinimumSyncFrequency
    static [hashtable]$Config

    static [void] Set_GCloudProperties ([hashtable]$propertiesToSet) {
        [GCloud]::Config = $propertiesToSet
        $propertiesToSet.GetEnumerator() | ForEach-Object {
            [GCloud]::$($_.Key) = $_.Value
        }
    }
}