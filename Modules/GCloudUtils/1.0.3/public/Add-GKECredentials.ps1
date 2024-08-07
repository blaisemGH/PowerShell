function Add-GKECredentials {
    [CmdletBinding(DefaultParameterSetName = 'ViaProjectID' )]
    Param(
        [Parameter(ParameterSetName = 'ViaProjectID' )]
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

        [Parameter(Mandatory, ParameterSetName = 'ViaProjectID')]
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
        [string]$ProjectID,

        [Parameter(Mandatory, ParameterSetName = 'ViaLocalFilesystem', ValueFromRemainingArguments )]
        [Alias('fs')]
        [GCloudProjectCacheInFSCompletions()]
        [string]$IDFromFS,

        [Alias('key')]
        [string]$NewMapKey,

        [switch]$SkipAddMapKey,
        [switch]$ForceAddMapKey
    )

    $selectedProjectID = & {
        if ($PSCmdlet.ParameterSetName -eq 'ViaLocalFilesystem') {
            Split-Path ($IDFromFS -join '') -Leaf
        }
        else {
            $ProjectID
        }
    }

    $alreadyMappedContexts = if ( Test-Path ([Kube]::ContextFile) ) {
        (Import-PowerShellDataFile ([Kube]::ContextFile)).Values
    }
    else { [Kube]::MappedContexts.Values }

    $clusterGKEInfo = $selectedProjectID | Get-GCloudGkeClusterInfoFromProjectId

    gcloud container clusters get-credentials $clusterGKEInfo.Name --location $clusterGKEInfo.Location --project $selectedProjectID

    if ( $? ) {
        if ( $ForceAddMapKey -or (!$SkipAddMapKey -and  ($alreadyMappedContexts -eq $clusterGKEInfo.Context) )) {
            Update-ContextFileMap -ProjectID $selectedProjectID -NewMapKey $NewMapKey -ErrorAction Stop | Export-ContextFileAsPSD1
        }

        gcloud config set project $selectedProjectID
        [GCloud]::CurrentProject = $selectedProjectID
    }
}
