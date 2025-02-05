using namespace System.Management.Automation
using namespace System.Collections.Generic
using namespace System.Text
using namespace System.Management.Automation
function Set-KubeMappedContexts {
    param (
        [Parameter(Mandatory)]
        [string]$FilePathOfContexts, #= ([Kube]::ContextFile),

        [Parameter(Mandatory,ValueFromPipeline, ParameterSetName='MapEntry')]
        [alias('contexts','c')]
        [hashtable[]]$KubeContexts,

        [Parameter(Mandatory,ValueFromPipelineByPropertyName, ParameterSetName='KeyValueSeparate')]
        [string[]]$Key,
        [Parameter(Mandatory,ValueFromPipelineByPropertyName, ParameterSetName='KeyValueSeparate')]
        [string[]]$Value
    )
    
    begin {
        if ( !$FilePathOfContexts -or !(Test-Path $FilePathOfContexts) ) {
            $err = "Fatal! Could not find the context file path: $FilePathOfContexts"
            $errorRecord = [ErrorRecord]::new($err, $null, 'ObjectNotFound', $null)
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }
        $stringBuilder = [StringBuilder]::new('@{').AppendLine()
    }
    process {
        $setContexts = & {
            if ( $PSCmdlet.ParameterSetName -eq 'KeyValueSeparate' ) {
                if ( $Key.Count -ne $Value.Count ) {
                    $err = "Counted $($Key.Count) keys and $($Value.Count) values. These must be equal!"
                    $PSCmdlet.ThrowTerminatingError([ErrorRecord]::new($err, 'UnequalCount', 'InvalidArgument',$null))
                }
                $k = [list[string]]$Key
                $v = [list[string]]$Value
                [Linq.Enumerable]::Zip($k,$v) |
                    Select-Object @{'label' = 'Key'; e = {$_.item1}}, @{l = 'Value'; e = {$_.item2}}
            }
            else {
                $KubeContexts.GetEnumerator()
            }
        }
        # Note $setContexts can have 2 different types based on the above control flow: a PSCustomObject or HashTableEnumerator.
        $setContexts | ForEach-Object {
            $key, $value = $_.Key, $_.Value
            $contextEntry = "`t'$key' = '$value'"
            $null = $stringBuilder.AppendLine($contextEntry)
        }
    }
    end {
        $null = $stringBuilder.AppendLine('}')
        Set-Content -LiteralPath $FilePathOfContexts -Value $stringBuilder.ToString() -Force
    }
}