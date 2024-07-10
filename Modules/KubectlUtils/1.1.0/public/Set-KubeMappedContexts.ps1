using namespace System.Management.Automation
using namespace System.Collections.Generic
using namespace System.Text
function Set-KubeMappedContexts {
    param (
        [Parameter(Mandatory,ValueFromPipeline, ParameterSetName='MapEntry')]
        [alias('contexts','c')]
        [hashtable[]]$KubeContexts,

        [Parameter(Mandatory,ValueFromPipelineByPropertyName, ParameterSetName='KeyValueSeparate')]
        [string[]]$Keys,
        [Parameter(Mandatory,ValueFromPipelineByPropertyName, ParameterSetName='KeyValueSeparate')]
        [string[]]$Values

    )
    begin {
        $stringBuilder = [StringBuilder]::new('@{').AppendLine()
    }
    process {
        $setContexts = & {
            if ( $PSCmdlet.ParameterSetName -eq 'KeyValueSeparate' ) {
                if ( $Keys.Count -ne $Values.Count ) {
                    $err = "Counted $($Keys.Count) keys and $($Values.Count) values. These must be equal!"
                    $PSCmdlet.ThrowTerminatingError([ErrorRecord]::new($err, 'UnequalCount', 'InvalidArgument',$null))
                }
                $k = [list[string]]$Keys
                $v = [list[string]]$Values
                [Linq.Enumerable]::Zip($k,$v) |
                    Select-Object @{'label' = 'Key'; e = {$_.item1}}, @{l = 'Value'; e = {$_.item2}}
            }
            else {
                $KubeContexts
            }
        }
        $setContexts.GetEnumerator() | ForEach-Object {
            $key, $value = $_.Key, $_.Value
            $contextEntry = "`t'$key' = '$value'"
            $null = $stringBuilder.AppendLine($contextEntry)
        }
    }
    end {
        $null = $stringBuilder.AppendLine('}')
        Set-Content -LiteralPath ([Kube]::ContextFile) -Value $stringBuilder.ToString() -Force
    }
}