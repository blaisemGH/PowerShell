using namespace System.Collections.Generic
Function Get-KubeResource {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, Position = 0)]
        [string]$ResourceName,

        [Parameter(Position = 1)]
        [Alias('i')]
        [ArgumentCompleter({
            param($cmdName, $paramName, $wordToComplete, $cmdAst, $fakeBoundParameters)
            if ( $fakeBoundParameters.ResourceName ) {
                return (
                    kubectl get $fakeBoundParameters.ResourceName -o name | ForEach { $_ -split '/' | Select-Object -Last 1 } | Where {$_ -like "$wordToComplete*"}
                )
            }
        })]
        [string]$ItemName,

        [Parameter(Position = 2)]
        [Alias('o')]
        [ValidateSet('wide','json','yaml','name')]
        [string]$OutputType = 'json',
        
        [string]$Namespace = [Kube]::Checkpoint_CurrentNamespace()
    )
    $getName = Switch ($ResourceName) {
        { $_ -in 'p','pod'    } { 'pods'            }
        { $_ -in 'd'        } { 'deploy'        }
        { $_ -in 's'        } { 'services'        }
        { $_ -in 'st'        } { 'statefulsets'    }
        { $_ -in 'j'        } { 'jobs'            }
        { $_ -in 'i'        } { 'ingress'        }
        DEFAULT { $_ }
    }
    
    <#
    $cmd = [Text.StringBuilder]::new()
    [void]$cmd.AppendLine("kubectl -n $Namespace get $getName")
    if ($itemName) {
        [void]$cmd.AppendLine($itemName)
    }
    if ( $outputType -eq 'json' ) {
        [void]$cmd.AppendLine('-o json | ConvertFrom-Json')
    }
    ElseIf ( $outputType -eq 'yaml' ) {
        [void]$cmd.AppendLine('-o yaml')
    }
    ElseIf ( $outputType -match '^name' ) {
        [void]$cmd.AppendLine('-o name')
    }
    ElseIf ($outputType) {
        [void]$cmd.AppendLine("-o $outputType | ForEach { `$_ -replace ' {2,}', '#' } | ConvertFrom-Csv -Delimiter '#'")
    }
    Else {
        [void]$cmd.AppendLine("| ForEach { `$_ -replace ' {2,}', '#' } | ConvertFrom-Csv -Delimiter '#'")
    }

    $o = $out = I-E ( $cmd.ToString() -replace [Environment]::NewLine, ' ' )
#>
    $kubeArgs = [List[string]]::new()
    $kubeArgs.Add("--namespace=$Namespace")
    $kubeArgs.Add('get')
    $kubeArgs.Add("$getName")
    if ( $outputType ) {
        $kubeArgs.Add("--output=$outputType")
    }
    $kubectlOutput = kubectl @kubeArgs
    $psObjectOutput = switch ($OutputType) {
        json { $kubectlOutput | ConvertFrom-Json }
        yaml { if ( Get-Command ConvertFrom-Yaml) { $kubectlOutput | ConvertFromYaml } else { $kubectlOutput }}
        name { $kubectlOutput }
        DEFAULT { $kubectlOutput -replace '\t', '    ' -replace '\s{2,}', [char]0x2561 | ConvertFrom-Csv -Delimiter ([char]0x2561) }
    }
    if ( !$psObjectOutput ) { break }

    $noItemsOutput = if ($psObjectOutput | Get-Member -Membertype NoteProperty -Name items) {
        $psObjectOutput.items
    } else { $psObjectOutput }

    If ( $PSBoundParameters.OutVariable ) {
        Return $noItemsOutput
        Write-Host ($noItemsOutput | Format-Table)
    }
    Else {
        $script:k = $noItemsOutput
        $noItemsOutput | Format-Table -AutoSize -Wrap
    }
}
