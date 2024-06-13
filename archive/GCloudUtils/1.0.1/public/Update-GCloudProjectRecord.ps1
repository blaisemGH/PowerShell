Function Update-GCloudProjectRecord {
    if ( ! (Test-Path ([GCloud]::PathToProjectCSV) )) {
        New-Item ([GCloud]::PathToProjectCSV) -ItemType File -Force
    }

    (gcloud projects list) -replace
        '\s{2,}', [char]0x2561 |
            ConvertFrom-Csv -Delimiter ([char]0x2561) |
                Export-Csv -LiteralPath ([GCloud]::PathToProjectCSV) -Force -Delimiter ','
}