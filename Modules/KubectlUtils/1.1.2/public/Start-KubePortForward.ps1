function Start-KubePortForward {
    [CmdletBinding(DefaultParameterSetName='serviceToLocal')]
    param(
        [Parameter(Mandatory, ParameterSetName='serviceToLocal', Position=0)]
        [KubeServiceCompletions()]
        [string]$Service,

        [Parameter(ParameterSetName='serviceToLocal')]
        [KubeNamespaceCompletions()]
        [string]$Namespace,

        [Parameter(ParameterSetName='serviceToLocal')]
        [string]$LocalPort,

        [Parameter(ParameterSetName='serviceToLocal')]
        [ValidateScript({
            $_ -eq 'LocalHost' || $_ -as [ipaddress]
        })]
        [string]$Address = '0.0.0.0',

        [Parameter(Mandatory, ParameterSetName='javaDebugger')]
        [KubePodCompletions()]
        [string]$DebugJVMPod
    )

    $ns = if ( $Namespace ) { "--namespace=$Namespace" }

    if ( $PSCmdlet.ParameterSetName -eq 'javaDebugger' ) {
        
        [string[]]$debugPorts = kubectl $ns get pod $DebugJVMPod -o yaml |
            Select-String agentlib |
            foreach {
                ($_.Line -split ':')[-1]
            }

        $port = if ( $debugPorts.Count -eq 1) { $debugPorts } else {
            Test-ReadHost -Query "Found multiple debug ports. Please enter a port to continue." -ValidationStrings $debugPorts
        }
        
        kubectl $ns port-forward $DebugJVMPod $port
        
        break
    }
    
    $targetPort = (kubectl $ns describe service $Service | Select-String '(?<=^TargetPort:\s+)\d+').Matches.Groups[0].Value

    if ( !$targetPort ) {
        $errMsg = "Could not locate the target port parameter for service $Service"
    }
    if ( $targetPort -is [Collections.IList] ) {
        $errMsg = "Found more than 1 targetPort for service $Service. Ports: $($targetPort | Out-String)"
    }
    if ( $errMsg ) {
        $errorRecord = [Management.Automation.ErrorRecord]::new($errMsg,'InvalidTargetPort','InvalidData',$null)
        $PSCmdlet.ThrowTerminatingError($errorRecord)
    }
    
    $portForward = if ( $LocalPort ) { $LocalPort } else { Write-Host "`nParameter LocalPort not provided. Using target port: $targetPort" -Fore Yellow; $targetPort }

    $logArguments = [pscustomobject]@{
        Namespace = if ( $Namespace ) { $Namespace } else { [Kube]::CurrentNamespace }
        Service = $Service
        TargetPort = $targetPort
        LocalPort = $portForward
        Address = $Address
    }

    Write-Host "`nkubectl port forward parameters:" -ForegroundColor Cyan
    Write-Host ($logArguments | Format-List | Out-String)
    
    kubectl $ns port-forward --address=$Address service/$Service ${targetPort}:$portForward
}