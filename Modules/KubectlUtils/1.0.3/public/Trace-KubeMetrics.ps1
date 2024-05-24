using namespace System.IO

Function Trace-KubeMetrics {
    [CmdletBinding(DefaultParameterSetName='unlimitedDurationNoRollover')]
    Param(
        [int]$IntervalOfOutputInSeconds = 20,
        [Parameter(Mandatory)]
        [alias('path')]
        [ConvertToFullPathTransform()]
        [string]$OutputFile,
        
        [Parameter(ParameterSetName='minutes')]
        [int]$MinutesDuration,
        
        [Parameter(ParameterSetName='hours')]
        [int]$HoursDuration,
        
        [switch]$ForceNewFile,
        
        [ArgumentCompleter(
            {
                # See Get-KubeMetrics for a description of what this is doing, as it uses the same ArgumentCompleter.
                Param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $lastElement = $commandAst.CommandElements[-1]
                $paramTokens = $lastElement.Value + $LastElement.Elements.Value | Where-Object {$_}
                $lastTokenToComplete = $paramTokens | Select-Object -Last 1
                $alreadyUsedTokens = $paramTokens + $LastElement.NestedAst.Value | Where-Object {$_}

                [Kube]::Get_Namespaces() + "'--all-namespaces'" + "'-A'" | Where-Object {
                    $_ -like "$lastTokenToComplete*" -and
                    $_ -notin $alreadyUsedTokens
                }
            }
        )]
        [string[]]$Namespaces = (kubectl config view --minify -o json | ConvertFrom-Json).contexts.context.namespace,

        [ValidateSet('Default','All','Custom')]
        [string]$ViewFilter = 'Default',

        
        [ValidateScript({
            ($_ -as [double]) -gt 500 -or
            $_ -match '(?i)^[0-9.]+[a-z]?[b]$'
        })]
        [string]$RolloverSize,

        [int]$RolloverHours

    )

    If ( (Test-Path $outputFile) -and $ForceNewFile ) {
        Remove-Item $outputFile -Force -ErrorAction Stop
    }

    $lambdaWriteMetricsEntry = { Param ($outputFile)
        If ( ! (Test-Path $outputFile) ) {
            Set-Content -Path $outputFile -value '['
        }
        Else {
            $f = [File]::ReadAllLines($outputFile)
            $f[-1] = ','
            Set-Content -Path $outputFile -Value $f -ErrorAction Stop
        }
        (Get-KubeMetrics -Namespaces $Namespaces -ViewFilter $viewFilter |
            ConvertTo-Json -Depth 10 |
            Foreach-Object ToCharArray |
            Select-Object -Skip 1
        ) -join '' | Add-Content -Path $outputFile
        
        Start-Sleep -Seconds $IntervalOfOutputInSeconds
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

    $fmtRolloverSize = & {
        $sizes = $RolloverSize -split '(?=[a-zA-Z]+$)'
        if ( $sizes.count -gt 1 ) {
            $sizes[0] / ('1' + $sizes[1])
        }
        else { $sizes[0] }
    }

    Write-Host ([Environment]::NewLine + 'Output file: ') -NoNewLine; Write-Host ($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($outputFile)) -Fore Cyan
    Write-Host 'Streaming interval: ' -NoNewLine; Write-Host $IntervalOfOutputInSeconds -Fore Yellow -NoNewline; Write-Host ' seconds'

    If ($endTime -is [datetime]) {
        Write-Host "Streaming kube metrics to output file until $($endTime -as [datetime]). Press ctrl + C to cancel early."
        While ( (Get-Date) -lt $endTime ) {
            if ( $RolloverSize -or $RolloverHours ) {
                $statsOutputFile = Get-Item $outputFile
                if ( $statsOutputFile.Length -gt $fmtRolloverSize -or (Get-Date) -gt (Get-Date).AddHours($RolloverHours) ) {
                    $increment = [int]($statsOutputFile.Basename -split '[.]')[-1] + 1
                    $rolledoverFilename = Join-Path $statsOutputFile.DirectoryName ( $statsOutputFile.Basename + '.' + $increment + $statsOutputFile.Extension)
                    try {
                        Move-Item $outputFile -Destination $rolledoverFilename -ErrorAction Stop
                        Set-Content -Path $outputFile -value '['
                    } catch {}
                }
            }
            & $lambdaWriteMetricsEntry $outputFile
        }
    }
    Else {
        Write-Host "Streaming kube metrics to output file... Press ctrl + C to cancel when done"
        While ( $true ) {
            & $lambdaWriteMetricsEntry $outputFile
        }
    }
}
