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

        [Parameter(Mandatory, ParameterSetName = 'GkeInfoParams')]
        [GCloudProjectCacheInFSCompletions()]
        [string]$GkeName,

        [Parameter(Mandatory, ParameterSetName = 'GkeInfoParams' )]
        [GCloudProjectCacheInFSCompletions()]
        [string]$GkeLocation,

        [Parameter(Mandatory, ParameterSetName = 'GkeInfoObject', ValueFromPipeline )]
        [GCloudProjectCacheInFSCompletions()]
        [GCloudGkeInfo]$GkeInfo,

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

    if ( $PSCmdlet.ParameterSetName -eq 'GkeInfoParams' ) {
        gcloud container clusters get-credentials $GkeName --location $GkeLocation --project $selectedProjectID    
    }
    elseif ( $PSCmdlet.ParameterSetName -eq 'GkeInfoObject' ) {
        gcloud container clusters get-credentials $GkeInfo.Name --location $GkeInfo.Location --project $selectedProjectID
    }
    else {
        $gkeMetaInformation = try {
            Get-ChildItem ([GCloud]::ProjectRoot) -File -Filter "*$projectId" -ErrorAction Stop | Get-Content | ConvertFrom-StringTable -ErrorAction Stop
        } catch {
            $null
        }
        
        if ( $gkeMetaInformation.Name -and $gkeMetaInformation.Location ) {
            gcloud container clusters get-credentials $gkeMetaInformation.Name --location $gkeMetaInformation.Location --project $selectedProjectID
        } else {
            $clusterGKEInfo = $selectedProjectID | Get-GCloudGkeClusterInfoFromProjectId
            gcloud container clusters get-credentials $clusterGKEInfo.Name --location $clusterGKEInfo.Location --project $selectedProjectID
        }
    }

    
    if ( $? ) {
        $alreadyMappedContexts = if ( Test-Path ([Kube]::ContextFile) ) {
            (Import-PowerShellDataFile ([Kube]::ContextFile)).Values
        }
        else { [Kube]::MappedContexts.Values }

        if ( $ForceAddMapKey -or (!$SkipAddMapKey -and  ($alreadyMappedContexts -eq $clusterGKEInfo.Context) )) {
            Update-ContextFileMap -ProjectID $selectedProjectID -NewMapKey $NewMapKey -ErrorAction Stop | Export-ContextFileAsPSD1
        }

        gcloud config set project $selectedProjectID
        [GCloud]::CurrentProject = $selectedProjectID
    }
}