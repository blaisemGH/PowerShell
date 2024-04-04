Class g {
    static [string]$PathToProjectCSV = "$HOME/.pwsh/gcloud/projects.csv"
    static [string]$ProjectRoot = "$HOME/.pwsh/gcloud/projects"
    static [string]$OrganizationNumber = ''
    static [string]$FilterProjects = '.*'
    static [hashtable]$Config
    static [scriptblock]$InitializationScript = (
        [ScriptBlock]::create( @"

            `$moduleHome = $PSScriptRoot
            <#
            `$manifest = Import-PowerShellDataFile `$moduleHome/../GCloudUtils.psd1
            Foreach ( `$requiredModule in `$manifest.RequiredModules ) {
                Import-Module `$requiredModule
            }
            Foreach ( `$nestedModule in `$manifest.NestedModules ) {
                Import-Module `$nestedModule
            }
            ForEach ( `$moduleScript in `$manifest.ScriptsToProcess ) {
                . `$moduleScript
            }#>
            `$moduleHome > C:\git\PowerShell\Modules\GCloudUtils\1.0.1\public\test.txt
"@
        )
    )

    static [void] Set_GCloudProperties ([hashtable]$propertiesToSet) {
        [G]::Config = $propertiesToSet
        $propertiesToSet.GetEnumerator() | ForEach-Object {
            [G]::$($_.Key) = $_.Value
        }
    }
}