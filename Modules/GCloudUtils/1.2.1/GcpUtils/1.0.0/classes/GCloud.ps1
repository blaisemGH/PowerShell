Class GCloud {
    static [string]$LocalCache = "$HOME/.pwsh/gcloud/"
    static [string]$PathToProjectCSV = ( Join-Path ([GCloud]::LocalCache) projects.csv )
    static [string]$PathToProjectGkeMappings = ( Join-Path ([GCloud]::LocalCache) gcloudContexts.psd1 )
    static [string]$ProjectRoot = ( Join-Path ([GCloud]::LocalCache) projects )
    static [string]$OrganizationNumber = ''
    static [string]$FilterProjectIds = '.*'
    static [string]$FilterProjectNames = '.*'
    static [string]$PatternForNonGkeProjects
    static [hashtable]$CompletionTree
    static [int]$MinimumSyncFrequency
    static [hashtable]$Config
    static [scriptblock]$NewGKEContextKey = {
        param(
            [Parameter(Mandatory)]
            $ProjectLocalFilepath
        )
        return (Get-ChildItem ([GCloud]::ProjectRoot) -Recurse -File -Filter $ProjectLocalFilepath).FullName -replace '/','-'
    }

    static [string]$CurrentProject = ( gcloud config list 2> $null | Select-String 'project = ' | ForEach { $_.Line -split ' = ' | Select-Object -Last 1 } )

    static [void] SetGCloudProperties ([hashtable]$propertiesToSet) {
        [GCloud]::Config = $propertiesToSet
        $propertiesToSet.GetEnumerator() | ForEach-Object {
            [GCloud]::$($_.Key) = $_.Value
        }
    }
}