using namespace System.Management.Automation

Function Copy-KubeFile {
    [CmdletBinding(DefaultParameterSetName='inferDirection')]
    Param(
        [Parameter(Mandatory, Position=0)]
        [alias('pod', 'p')]
        [string]$PodName,
        [Parameter(Mandatory, Position=1)]
        [ArgumentCompleter(
            {
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $pod = $fakeBoundParameters.PodName
                $namespace = $fakeBoundParameters.Namespace
                if ( $namespace ) { $ns = "-n $namespace"}
                $lsCmd = "ls -dlA $wordToComplete*"
                [string[]]@(kubectl $ns exec $pod -- sh -c $lsCmd) |
                    ForEach {
                        if ( $_ -match '^l' ) {
                            ($_ -split ' ')[-3]
                        }
                        elseif ( $_ -match '^d' ) {
                            ($_ -split ' ')[-1] + '/'
                        }
                        Else {
                            ($_ -split ' ')[-1]
                        }
                    } |
                    Where-Object {
                        $_ -like "$wordToComplete*"
                    }
            }
        )]
        [alias('r')]
        [string]$RemotePath,
        [Parameter(Mandatory, Position=2)]
        [alias('l')]
        [string]$LocalPath='.',
        [Parameter(Position=3)]
        [int]$retries,
        [Parameter(Mandatory,ParameterSetName='download')]
        [Alias('d')]
        [switch]$Download,
        [Parameter(Mandatory,ParameterSetName='upload')]
        [alias('u')]
        [switch]$Upload,
        [Alias('n')]
        [string]$Namespace,
        [ArgumentCompleter(
            {
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $pod = $fakeBoundParameters.PodName
                $namespace = $fakeBoundParameters.Namespace
                if ( $namespace ) { $ns = "-n $namespace"}

                $podConfig = kubectl $ns get pod $pod -o json | ConvertFrom-Json
                $status = $podConfig.status.phase
                $containers = if ( $status -eq 'RUNNING' ) {
                    $podConfig.spec.containers.name
                } else {
                    $podConfig.spec.initContainers.name
                }
                $containers | Where-Object {
                        $_ -like "$wordToComplete*"
                    }
            }
        )]
        [Alias('c')]
        [string]$Container
    )
    $podPath = if ( $Namespace ) {
        "${Namespace}/${PodName}:$RemotePath"
    }
    else {
        "${PodName}:$RemotePath"
    }
    if ( ! Test-Path $LocalPath -IsValid ) {
        $err = [ErrorRecord]::new("Value for LocalPath parameter is not a valid path! Input value: $LocalPath", $null, 'ItemNotFoundException', $null)
        $PSCmdlet.ThrowTerminatingError($err)
    }


    If ( $PSCmdlet.ParameterSetName -eq 'inferDirection' ) {
        $direction = & {
            If ( !(Test-Path $LocalPath -PathType Leaf) ) {
                'download'
            }
            ElseIf ( $RemotePath -match '(?<![\\])/$' ) {
                'upload'
            }
            Else {
                Test-ReadHost 'cp which direction?[download|upload]' -ValidationStrings 'download','d','upload','u'
                Write-Host 'Next time, preempt this question by adding the argument -d or -u for download or upload respectively, or imply the direction by either ending the RemotePath with a / (upload) or setting the LocalPath to a directory, a non-existent file, or a "." (download).'
            }
        }
    }

    $resolvedLocalParentPath = try {
        Resolve-Path -LiteralPath $LocalPath -Relative -ErrorAction Stop
    } catch [System.Management.Automation.ItemNotFoundException] {
        Resolve-Path -LiteralPath (Split-Path $LocalPath -Parent) -Relative -ErrorAction Stop
    }    
    $resolvedLocalFullPath = If ( $LocalPath -eq '.' ) {
        $localFilename = Split-Path $RemotePath -Leaf
        Join-Path $resolvedLocalParentPath $localFilename
    } else {
        $resolvedLocalParentPath
    }

    If ( $Upload -or $direction -in 'upload', 'u') {
        kubectl cp (Resolve-Path -LiteralPath $LocalPath -Relative) $podPath --retries $retries
    }
    If ( $Download -or $direction -in 'download', 'd') {
        kubectl cp $podPath $resolvedLocalFullPath --retries $retries
    }
}
