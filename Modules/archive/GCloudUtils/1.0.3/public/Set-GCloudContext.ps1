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
        Add-GKECredentials -ProjectId $projectId

        $null = New-Event -SourceIdentifier 'Set-KubeContext' -EventArguments $gkeContext
        Invoke-Expression ([Kube]::Initialize_KubeApiAutocomplete($true))
        Update-KubeCompletions
    }
    else {
        Set-KubeContext -Context $gkeContext
    }

    [GCloud]::CurrentProject = $projectId
}
