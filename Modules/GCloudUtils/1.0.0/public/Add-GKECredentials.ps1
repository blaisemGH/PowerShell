function Add-GKECredentials {
    Param(
        [ArgumentCompleter(
            {
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                (gcloud projects list) -replace '\s{2,}', [char]0x2561 | 
                    ConvertFrom-Csv -Delimiter ([char]0x2561) | Where {
                        ($_.Name -replace '\s') -like ("$wordToComplete*" -replace '\s')
                    } | Sort-Object Name | Select-Object -expandProperty Name | % { $_ -replace '\s'}
            }
        )]
        [Alias('filter')]
        [string]$NameFilter,

        [Parameter(Mandatory)]
        [ArgumentCompleter(
            {
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $namefilter = if ( $fakeBoundParameters.NameFilter ) { $fakeBoundParameters.NameFilter} else { '*' }
                (gcloud projects list) -replace '\s{2,}', [char]0x2561 | 
                    ConvertFrom-Csv -Delimiter ([char]0x2561) | Where {
                        ($_.Name -replace '\s') -like $nameFilter -and $_.Project_ID -like "$wordToComplete*"
                    } | Select-Object -exp Project_ID
            }
        )]
        [Alias('ID')]
        [string]$ProjectID,
        [Alias('key')]
        [string]$NewMapKey
    )

    $clusterGKEInfo = (gcloud container clusters list --project $ProjectID) -replace '\s{2,}', [char]0x2561 | ConvertFrom-Csv -Delimiter ([char]0x2561)

    if ( ! $clusterGKEInfo.Name ) {
        $err = [System.Management.Automation.ErrorRecord]::new("Empty output from command: gcloud container clusters list --project $ProjectID", $null, 'ObjectNotFound', $null)
        $PSCmdlet.ThrowTerminatingError($err)
    }
    gcloud container clusters get-credentials $clusterGKEInfo.Name --location $clusterGKEInfo.Location --project $ProjectID
    Update-ContextFileMap -ProjectID $ProjectID -NewMapKey $NewMapKey -ErrorAction Stop | Export-ContextFileAsPSD1
}
