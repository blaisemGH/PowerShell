Class GCloud {
    static [string]$PathToProjectCSV = "$HOME/.pwsh/gcloud/projects.csv"
    static [string]$PathToProjectGkeMappings = "$HOME/.pwsh/KubectlUtils/gcloudContexts.psd1"
    static [string]$ProjectRoot = "$HOME/.pwsh/gcloud/projects"
    static [string]$OrganizationNumber = ''
    static [string]$FilterProjectIds = '.*'
    static [string]$FilterProjectNames = '.*'
    static [int]$MinimumSyncFrequency
    static [hashtable]$Config
    static [scriptblock]$NewGKEContextKey = {
        param(
            [Parameter(Mandatory)]
            $ProjectLocalFilepath
        )
        return $ProjectLocalFilepath -replace '/','-'
    }

    static [string]$CurrentProject = ( $null = gcloud config list | Select-String 'project = ' | ForEach { $_.Line -split ' = ' | Select-Object -Last 1 } )

    static [void] Set_GCloudProperties ([hashtable]$propertiesToSet) {
        [GCloud]::Config = $propertiesToSet
        $propertiesToSet.GetEnumerator() | ForEach-Object {
            [GCloud]::$($_.Key) = $_.Value
        }
    }
}