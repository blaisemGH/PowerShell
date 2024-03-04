using namespace System.Management.Automation

function Copy-KubeFile {
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
                if ( $namespace ) { $ns = "-n=$namespace"}
                $lsCmd = "ls -dlA $wordToComplete*"
                [string[]]@(kubectl $ns exec $pod -- sh -c $lsCmd) |
                    ForEach {
                        if ( $_ -match '^l' ) {
                            ($_ -split ' ')[-3]
                        }
                        elseif ( $_ -match '^d' ) {
                            ($_ -split ' ')[-1] + '/'
                        }
                        else {
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
                if ( $namespace ) { $ns = "-n=$namespace"}

                $podConfig = kubectl $ns get pod $pod -o json | ConvertFrom-Json
                $status = $podConfig.status.phase
                $containers = & {
                    if ( $status -eq 'RUNNING' ) {
                        $podConfig.spec.containers.name
                    } else {
                        $podConfig.spec.initContainers.name
                    }
                }

                $containers | Where-Object {
                    $_ -like "$wordToComplete*"
                }
            }
        )]
        [Alias('c')]
        [string]$Container,
        [switch]$ShowProgress
    )
    $podPath, $ns = if ( $Namespace ) {
        "${Namespace}/${PodName}:$RemotePath"
        "-n $Namespace"
    }
    else {
        "${PodName}:$RemotePath"
    }
    if ( ! (Test-Path $LocalPath -IsValid) ) {
        $err = [ErrorRecord]::new("Value for LocalPath parameter is not a valid path! Input value: $LocalPath", $null, 'ItemNotFoundException', $null)
        $PSCmdlet.ThrowTerminatingError($err)
    }


    if ( $PSCmdlet.ParameterSetName -eq 'inferDirection' ) {
        $direction = & {
            if ( !(Test-Path $LocalPath -PathType Leaf) ) {
                'download'
            }
            elseif ( $RemotePath -match '(?<![\\])/$' ) {
                'upload'
            }
            else {
                Test-ReadHost 'cp which direction?[download|upload]' -ValidationStrings 'download','d','upload','u'
                Write-Host 'Next time, preempt this question by adding the argument -d or -u for download or upload respectively, or imply the direction by either ending the RemotePath with a / (upload) or setting the LocalPath to a directory, a non-existent file, or a "." (download).'
            }
        }
    }

    # Need to use resolve path on Windows to transform it into a relative path and avoid the ':' in full paths, e.g., 'C:/', which breaks kubectl.
    $resolvedLocalBasePath = try {
        Resolve-Path -LiteralPath $LocalPath -Relative -ErrorAction Stop
    } catch [System.Management.Automation.ItemNotFoundException] {
        Resolve-Path -LiteralPath (Split-Path $LocalPath -Parent) -Relative -ErrorAction Stop
    }    
    $resolvedLocalFullPath = & {
        if ( $LocalPath -eq '.' ) {
            $localFilename = Split-Path $RemotePath -Leaf
            Join-Path $resolvedLocalBasePath $localFilename
        }
        else {
            $resolvedLocalBasePath
        }
    }

    if ( $Upload -or $direction -in 'upload', 'u') {
        $cmd = "kubectl cp $resolvedLocalFullPath $podPath --retries $retries"
        
        # Get the full remote filepath for the progress tracker
        $localPathFileName = Split-Path $resolvedLocalFullPath -Leaf
        $remoteFullPath = $(
            if ( (Split-Path $remotePath -Leaf) -ne $localPathFileName -and $remotePath -notmatch '[.][a-z]{2,5}$') {
                Join-Path $RemotePath $localPathFileName
            } else {
                $RemotePath
            }
        ) -replace [Regex]::Escape([System.IO.Path]::DirectorySeparatorChar), '/'

        $progressEnd = Get-Item $resolvedLocalFullPath | Select-Object -ExpandProperty Length
        $progressTracker = "return 1000 * ((kubectl $ns exec $PodName -- du -k $remoteFullPath) -split '\s' | Select-Object -first 1) / $progressEnd"
    }
    if ( $Download -or $direction -in 'download', 'd') {
        $cmd = "kubectl cp $podPath $resolvedLocalFullPath --retries $retries"
        
        $progressEnd = (kubectl $ns exec $PodName -- du -k $RemotePath) -split '\s' | Select-Object -First 1
        $progressTracker = "return (Get-Item $resolvedLocalFullPath | Select-Object -ExpandProperty Length) / (1000 * $progressEnd)"
    }

    if ( $ShowProgress ) {
        $ScriptTrackProgress = [ScriptBlock]::Create($progressTracker)
        [ProcessHelper]::new($cmd).Run($ScriptTrackProgress)
    }
    else {
        Invoke-Expression $cmd
    }
}
