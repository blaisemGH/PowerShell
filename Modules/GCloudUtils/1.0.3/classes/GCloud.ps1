Class GCloud {
    static [string]$LocalCache = "$HOME/.pwsh/gcloud/"
    static [string]$PathToProjectCSV = ( Join-Path ([GCloud]::LocalCache) projects.csv )
    static [string]$PathToProjectGkeMappings = ( Join-Path ([GCloud]::LocalCache) gcloudContexts.psd1 )
    static [string]$ProjectRoot = ( Join-Path ([GCloud]::LocalCache) projects )
    static [string]$OrganizationNumber = ''
    static [string]$FilterProjectIds = '.*'
    static [string]$FilterProjectNames = '.*'
    static [hashtable]$CompletionTree
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