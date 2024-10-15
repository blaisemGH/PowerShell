Function Enter-KubePod {
    Param(
        [Parameter(Mandatory, Position=0)]
        [alias('p')]
        [KubePodCompletions()]
        [string]$PodName,
        [Parameter(ValueFromRemainingArguments)]
        [alias('exec', 'e')]
        [ArgumentCompleter(
            #Tab completion for filepaths when $ExecCmd begins with ls, cat, or find. Must begin input with a quote to allow tab completion parsing.
            { 
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $formatWordToComplete = $wordToComplete -replace '^[''"]' -replace '[''"]$'
                #write-host $formatWordToComplete
                if ( $formatWordToComplete -match '^(ls|cat|find) (-[a-z]+ )*') {
                    $prefix = $Matches[0]
                    $pod = $fakeBoundParameters.PodName
                    $namespace = $fakeBoundParameters.Namespace
                    $container = $fakeBoundParameters.Container
                    if ( $namespace ) { $ns = "-n=$namespace"}
                    if ( $container ) { $ctr = "-c=$container"}
                    $pathToComplete = $formatWordToComplete -replace $prefix 
                    $lsCmd = "ls -dlA $pathToComplete*"
                    
                    return [string[]]@(kubectl $ns exec $pod $ctr -- sh -c $lsCmd) |
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
                            $_ -like "$pathToComplete*"
                        } | ForEach {
                            "'$prefix" + $_ 
                        }
                    
                }
            }
        )]
        [string]$ExecCmd = 'bash',
        [alias('ni')]
        [switch]$NotInteractive,
        [Alias('n')]
        [KubeNamespaceCompletions()]
        [string]$Namespace,
<#        [ArgumentCompleter(
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
        )]#>
        [alias('c')]
        [KubeContainerCompletions()]
        [string]$Container
    )
    $date = Get-Date
    # Using = sign inbetween arguments below, because a space is submitted as a separate argument by PowerShell to the kubectl command.
    $ns = if ( $Namespace ) { "-n=$Namespace" } else { $null } 
    $target = if ( $Container ) { "$PodName -c=$Container" } else { $PodName }
    $it = if ( $NotInteractive -or $ExecCmd -notin 'bash','sh') { $null } else { '-it' }

    kubectl $ns ( "exec $it $target -- $ExecCmd" -split ' +')
    if ( !$? -and $ExecCmd -eq 'bash' -and ((Get-Date) - $date).TotalSeconds -lt 2 ) {
        kubectl $ns ("exec $it $target -- sh" -split ' +')
    }
}
