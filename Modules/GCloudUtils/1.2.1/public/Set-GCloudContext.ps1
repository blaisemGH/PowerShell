Function Set-GCloudContext {
    Param(
        [Parameter(Mandatory)]
        [ArgumentCompleter(
            {
                Param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                [Kube]::MappedContexts.Values | Where-Object {
                    [string]$_ -like "$wordToComplete*"
                }
            }
        )]
        [string]$Context,

        [switch]$ForceRequestCustomContextMapping
    )

    $contextMap = [Kube]::MappedContexts
    $gkeContext = If ( $Context -in $contextMap.Keys ) {
        $contextMap.$Context
    } else {
        $Context
    }

    $projectId = ($gkeContext -split '_gke-')[1]

    $existingConfigContexts = kubectl config get-contexts -o name
    if ( $gkeContext -notin $existingConfigContexts -or $ForceRequestCustomContextMapping ) {
        $gkeMetaInformation = try {
            Get-ChildItem ([GCloud]::ProjectRoot) -File -Filter "*$projectId" -ErrorAction Stop | Get-Content | ConvertFrom-StringTable -ErrorAction Stop
        } catch {
            $null
        }
        
        if ( $gkeMetaInformation.Name -and $gkeMetaInformation.Location ) {
            Add-GKECredentials -GkeName $gkeMetaInformation.Name -GkeLocation $gkeMetaInformation.Location
        } else {
            Add-GKECredentials -ProjectId $projectId
        }

        #$null = New-Event -SourceIdentifier 'Set-KubeContext' -EventArguments $gkeContext
        [Kube]::Initialize_KubeApiAutocomplete($true)
        #Update-KubeCompletions
    }
    else {
        Set-KubeContext -Context $gkeContext
    }
}
