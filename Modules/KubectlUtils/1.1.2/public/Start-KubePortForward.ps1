function Start-KubePortForward {
    param(
        [Parameter(Mandatory, Position=0)]
        [KubeServiceCompletions()]
        [string]$Service,

        [KubeNamespaceCompletions()]
        [string]$Namespace,

        [string]$LocalPort,

        [ValidateScript({
            $_ -eq 'LocalHost' || $_ -as [ipaddress]
        })]
        [string]$Address = '0.0.0.0'
    )

    $ns = if ( $Namespace ) { "--namespace=$Namespace" }
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
    
    kubectl port-forward --address=$Address service/$Service ${targetPort}:$portForward
}