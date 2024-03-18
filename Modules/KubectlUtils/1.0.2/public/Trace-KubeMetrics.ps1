Function Trace-KubeMetrics {
    [CmdletBinding(DefaultParameterSetName='unlimitedDuration')]
    Param(
        [int]$IntervalOfOutputInSeconds = 20,
        [Parameter(Mandatory)]
        [alias('path')]
        [string]$outputFile,
        
        [Parameter(ParameterSetName='minutes')]
        [int]$minutesDuration,
        
        [Parameter(ParameterSetName='hours')]
        [int]$hoursDuration,
        
        [switch]$ForceNewFile,
        
        [string[]]$Namespaces = (kubectl get serviceaccounts default -o jsonpath='{.metadata.namespace}'),

        [ValidateSet('Default','All','Custom')]
        [string]$ViewFilter = 'Default'
    )
    If ( (Test-Path $outputFile) -and $ForceNewFile ) {
        Remove-Item $outputFile -Force -ErrorAction Stop
    }
    $lambdaGetMetrics = { Param ($outputFile)
        If ( ! (Test-Path $outputFile) ) {
            Set-Content -Path $outputFile -value '['
        }
        Else {
            Add-Content -Path $outputFile -Value ','
        }
        Get-KubeMetrics -Namespaces $Namespaces -ViewFilter $viewFilter | ConvertTo-Json -Depth 10 | Add-Content -Path $outputFile
        Start-Sleep -Seconds 20
    }
    
    $endTime = If ( $minutesDuration ) {
        (Get-Date).AddMinutes($minutesDuration)
    }
    ElseIf ( $hoursDuration ) {
        (Get-Date).AddHours($hoursDuration)
    }
    Else {
        $true
    }

    Write-Host ([Environment]::NewLine + 'Output file: ') -NoNewLine; Write-Host ($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($outputFile)) -Fore Cyan
    Write-Host 'Streaming interval: ' -NoNewLine; Write-Host $IntervalOfOutputInSeconds -Fore Yellow -NoNewline; Write-Host ' seconds'

    If ($endTime -is [datetime]) {
        Write-Host "Streaming kube metrics to output file until $($endTime -as [datetime]). Press ctrl + C to cancel early."
        While ( (Get-Date) -lt $endTime ) {
            & $lambdaGetMetrics $outputFile
        }
    }
    Else {
        Write-Host "Streaming kube metrics to output file... Press ctrl + C to cancel when done"
        While ( $true ) {
            & $lambdaGetMetrics $outputFile
        }
    }
}
