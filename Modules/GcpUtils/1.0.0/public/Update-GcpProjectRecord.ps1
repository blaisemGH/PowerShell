Function Update-GcpProjectRecord {
    [CmdletBinding()]
    param()

    if ( ! (Test-Path ([Gcp]::PathToProjectCSV) )) {
        New-Item ([Gcp]::PathToProjectCSV) -ItemType File -Force
    }

    Write-Verbose 'Updating list of Gcp projects'

    (gcloud projects list) -replace
        '\s{2,}', [char]0x2561 |
            ConvertFrom-Csv -Delimiter ([char]0x2561) |
                Export-Csv -LiteralPath ([Gcp]::PathToProjectCSV) -Force -Delimiter ','
    
    Write-Host "`nFinished syncing Gcp project list. See [Gcp]::PathToProjectCSV" -Fore Cyan
}