Function Enter-KubePod {
    Param(
        [Parameter(Mandatory, Position=0)]
        [alias('p')]
        [string]$PodName,
        [Parameter(ValueFromRemainingArguments)]
        [alias('r')]
        [string]$RunCmd = 'bash',
        [alias('ni')]
        [switch]$NotInteractive,
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
        [alias('c')]
        [string]$Container
    )
    $date = Get-Date
    # Using = sign inbetween arguments below, because a space is submitted as a separate argument by PowerShell to the kubectl command.
    $ns = if ( $Namespace ) { "-n=$Namespace" } else { $null } 
    $target = if ( $Container ) { "$PodName -c=$Container" } else { $PodName }
    $it = if ( $NotInteractive -or $RunCmd -notin 'bash','sh') { $null } else { '-it' }

    kubectl $ns ( "exec $it $target -- $RunCmd" -split ' +')
    if ( !$? -and $RunCmd -eq 'bash' -and ((Get-Date) - $date).TotalSeconds -lt 2 ) {
        kubectl $ns ("exec $it $target -- sh" -split ' +')
    }
}
