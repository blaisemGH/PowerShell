using namespace System.Management.Automation

function Copy-KubeFile {
    [CmdletBinding(DefaultParameterSetName='inferDirection')]
    Param(
        [Parameter(Mandatory, Position=0)]
        <# Add this later. It works now but need to remove argument register from Update-KubeCompletions.
           Probably refactor [kube] class instead to create a hashtable for lookups via $ns.$resource
        [ArgumentCompleter(
            {
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $namespace = $fakeBoundParameters.Namespace
                if ( $namespace ) { $ns = "-n=$namespace"}

                kubectl $ns get pods -o name | Where-Object {
                    $_ -like "$wordToComplete*"
                }
            }
        )]#>
        [KubePodCompletions()]
        [alias('pod', 'p')]
        [string]$PodName,
        [Parameter(Mandatory, Position=1)]
        [ArgumentCompleter(
            {
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $pod = $fakeBoundParameters.PodName
                $namespace = $fakeBoundParameters.Namespace
                $container = $fakeBoundParameters.Container
                if ( $container ) { $c = "-c=$container" }
                if ( $namespace ) { $ns = "-n=$namespace"}
                $lsCmd = "ls -dlA $wordToComplete*"
                [string[]]@(kubectl $ns exec $pod $c -- sh -c $lsCmd) |
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
    $containerArg = if ( $Container ) { "--container=$Container" }
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

    $doUpload = $doDownload = $false
    if ( $Upload -or  $direction -in 'upload', 'u' ) {
        $doUpload = $true
    } elseif  ( $Download -or $direction -in 'download', 'd') {
        $doDownload = $true
    } else {
        $errMsg = 'Could not resolve whether it''s a download or upload. Try specifying either -u or -d as an input argument'
        $err = [ErrorRecord]::new($errMsg, $null, 'InvalidOperation', $null)
        $PSCmdlet.ThrowTerminatingError($err)
    }

    # Need to use resolve path on Windows to transform it into a relative path and avoid the ':' in full paths, e.g., 'C:/', which breaks kubectl.
    $resolvedLocalPath = & {
        if ( $doUpload ) {
            try {
                Resolve-Path -LiteralPath $LocalPath -Relative -ErrorAction Stop
            }
            catch [System.Management.Automation.ItemNotFoundException] {
                $errMsg = "File to upload not found! Does $LocalPath exist? Resolve-Path error: $($_)"
                $err = [ErrorRecrd]::new($errMsg, $null, 'ObjectNotFound', $null)
                $PSCmdlet.ThrowTerminatingError($err)
            }
        }
        # kubectl cp expects a filename to be provided as the destination of a download. Must explicitly derive it here.
        elseif ( $LocalPath -eq '.' -or (Get-Item $LocalPath -ErrorAction SilentlyContinue).PSIsContainer ) {
            $localFilename = Split-Path $RemotePath -Leaf
            Join-Path (Resolve-Path -LiteralPath $LocalPath -Relative -ErrorAction Stop) $localFilename
        }
        else {
            # Need Resolve-Path for windows to remove drive letter, but the cmdlet errors if the target path doesn't exist.
            # This fails if you are downloading a file and setting its destination to a new file name, for example. The catch handles this.
            try {
                Resolve-Path -LiteralPath $LocalPath -Relative -ErrorAction Stop
            }
            catch [System.Management.Automation.ItemNotFoundException] {
                $parentLocalPath = & {
                    if ( Split-Path $LocalPath -Parent ) {
                        Split-Path $LocalPath -Parent
                    } else { (pwd).Path }
                }

                if ( ! (Test-Path $parentLocalPath )) {
                    if ( (Test-ReadHost "Directory $parentLocalPath does not exist. Create it?" -ValidationStrings 'yes','y','no','n') -in 'yes','y') {
                        mkdir $parentLocalPath
                    } else {
                        Write-Host "Exiting script. Reason: Nonexistent directory in target local path $LocalPath" -Fore Red
                        break
                    }
                }
                $fileLocalPath = Split-Path $LocalPath -Leaf
                Join-Path (Resolve-Path $parentLocalPath -Relative) $LocalPath
            }
        }
    }

    if ( $Upload -or $direction -in 'upload', 'u') {
        $cmd = "cp $resolvedLocalPath $podPath $containerArg --retries $retries" -replace ' {2,}', ' ' -split ' '
        
        # Get the full remote filepath for the progress tracker
        $localPathFileName = Split-Path $resolvedLocalPath -Leaf
        $remoteFullPath = $(
            if ( (Split-Path $remotePath -Leaf) -ne $localPathFileName -and $remotePath -notmatch '[.][a-z]{2,5}$') {
                Join-Path $RemotePath $localPathFileName
            } else {
                $RemotePath
            }
        ) -replace [Regex]::Escape([System.IO.Path]::DirectorySeparatorChar), '/'

        $progressEnd = Get-Item $resolvedLocalPath | Select-Object -ExpandProperty Length
        $progressTracker = "try {return 1000 * ((kubectl $ns exec $PodName $containerArg -- du -k $remoteFullPath) -split '\s' | Select-Object -first 1) / $progressEnd} catch [DivideByZeroException] { return 0 }"
    }
    if ( $Download -or $direction -in 'download', 'd') {
        $cmd = "cp $podPath $containerArg $resolvedLocalPath --retries $retries" -replace ' {2,}', ' ' -split ' '
        
        $progressEnd = (kubectl $ns exec $PodName $containerArg -- du -k $RemotePath) -split '\s' | Select-Object -First 1
        $progressTracker = "try {return (Get-Item $resolvedLocalPath -ErrorAction Stop | Select-Object -ExpandProperty Length) / (1000 * $progressEnd)} catch { return 0 }"
    }

    Write-Verbose "Executing command: $cmd"

    if ( $ShowProgress ) {
        Write-Debug $progressTracker
        $ScriptTrackProgress = [ScriptBlock]::Create($progressTracker)
        [ProcessHelper]::new('kubectl', $cmd).Run($ScriptTrackProgress)
    }
    else {
        kubectl $cmd
    }
}
