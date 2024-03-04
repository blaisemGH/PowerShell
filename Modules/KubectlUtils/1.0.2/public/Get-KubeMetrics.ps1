using namespace System.Management.Automation
using namespace System.Collections.Generic
using namespace System.Collections.ObjectModel

# Defines the output base type of the Get-KubeMetrics function.
class KubeMetrics {
    [datetime]$Datetime
    [string]$Namespace
    [string]$PodName
    [string]$Container
    [float]$CPU
    [float]$MemoryGB
}
# Define different subclasses, so that I can apply to each type a different view in the KubeMetrics.Format.ps1xml file, e.g., include namespace for View = All.
class KubeMetricsViewAll : KubeMetrics {}
class KubeMetricsViewCustom : KubeMetrics {}
class KubeMetricsViewDefault : KubeMetrics {}

function Get-KubeMetrics {
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromRemainingArguments)]
        [ArgumentCompleter(
            {
                # Enables tab completion for comma-delimited arguments to param -Namespaces
                Param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                # The current element being tab-completed is the last command element in the ast.
                $lastElement = $commandAst.CommandElements[-1]
                # Depending on the context, the current value may be in .Value or .Elements.Value (Can't remember my testing here tbh)
                $paramTokens = $lastElement.Value + $LastElement.Elements.Value | Where-Object {$_}
                # If somehow multiple values are returned, then presumably the last one is the one currently being tab completed.
                $lastTokenToComplete = $paramTokens | Select-Object -Last 1
                # Previously used tokens are in NestedAst.Value
                $alreadyUsedTokens = $paramTokens + $LastElement.NestedAst.Value | Where-Object {$_}

                [Kube]::Get_Namespaces() + "'--all-namespaces'" | Where-Object {
                    $_ -like "$lastTokenToComplete*" -and
                    $_ -notin $alreadyUsedTokens
                }
            }
        )]
        [string[]]$Namespaces = (kubectl config view --minify -o json | ConvertFrom-Json).contexts.context.namespace,

        [ValidateSet('Default','All','Custom')]
        [string]$ViewFilter = 'Default'
    )
    DynamicParam {
        # Enable $ViewFilter = 'Custom' to supply a new parameter to specify which containers.
        # This dynamic param takes precedence over [Kube]::relevantContainersFile (the default source of containers for $ViewFilter = 'Custom')
        $dynParams = [RuntimeDefinedParameterDictionary]::new()
        if ( $ViewFilter -eq 'Custom' ) {
            $attribute = [ParameterAttribute]::new()
            $attributeCollection1 = [Collection[System.Attribute]]@($attribute)
            $param1 = [RuntimeDefinedParameter]::new('FilterContainerNames', [string[]], $attributeCollection1)
            $dynParams.Add('FilterContainerNames', $param1)
        }
        return $dynParams
    }
    
    # Must use begin/process blocks because of DynamicParam, even though this function is not pipeline compatible.
    begin {
        $filterNamespaces = @(
            if ( $Namespaces -contains '--all-namespaces') {
                [Kube]::Get_Namespaces()
            } else {
                $Namespaces
            }
        )

        $filterContainers = switch ($ViewFilter) {
            # If $ViewFilter = 'Default', use kubectl to get all pod configs, as only kubectl calls populate the default container annotation.
            'Default' {
                if ( $filterNamespaces.count -eq 1 ) {
                    (kubectl -n $filterNamespaces[0] get pods -o json | ConvertFrom-Json).items.metadata
                } else {
                    (kubectl get pods -A -o json | ConvertFrom-Json).items.metadata
                }
            }
            # If $ViewFilter = 'Custom', define which custom containers should be filtered.
            'Custom' {
                if ( $PSBoundParameters.FilterContainerNames -and $PSBoundParameters.FilterContainerNames.Count -gt 0 ) {
                    $PSBoundParameters.FilterContainerNames
                } elseif ( [Kube]::relevantContainers -and [Kube]::relevantContainers.Count -gt 0) {
                    [HashSet[string]]@([Kube]::relevantContainers)
                } else {
                    $err = [ErrorRecord]::new( "Parameter 'View' was specified to $ViewFilter, but the accompanying parameter 'FilterContainers' was not provided, nor is     there a hashtable defined in $([Kube]::relevantContainersFile) that specifies a list of custom containers for key 'filterMetricontainers. This  view will always return zero output. Exiting...
                    ", $null, 'InvalidArgument', $null)
                    $PSCmdlet.ThrowTerminatingError($err)
                }
            }
        }

        # Default to the All view if more than 1 namespace was input, as the All view will display the namespaces in the default output.
        [type]$ViewClass = if ( $filterNamespaces.count -gt 1) {
          'KubeMetricsViewAll'
        } else { 'KubeMetricsView' + $ViewFilter }

        # Scrape the metrics from the kube metrics api and filter by namespaces.
        $apiScrapeDatetime = Get-Date
        $metrics = & {
            kubectl get --raw "/apis/metrics.k8s.io/v1beta1/pods" |
            ConvertFrom-Json |
            Select-Object -Exp items | 
            Where-Object {
                $_.metadata.namespace -in $filterNamespaces
            }
        }
    }

    process {
        return $metrics | ForEach-Object {
            $ns = $_.metadata.namespace
            $pod = $_.metadata.name
            $pipelineObject = $_ #Save pipeline variable so it can be referenced in the switch expression.
            $measuredContainers = switch ($ViewFilter) {
                All {
                    $pipelineObject | Measure-KubeContainers
                }
                Custom {
                    $pipelineObject | Measure-KubeContainers | Where-Object {$_.Container -in $filterContainers }
                }
                DEFAULT {
                    $defaultContainer = ($filterContainers | Where-Object {
                        $_.namespace -eq $ns -and $_.name -eq $pod
                    }).annotations.'kubectl.kubernetes.io/default-container'

                    if ($defaultContainer) {
                        $pipelineObject | Measure-KubeContainers | Where-Object {$_.Container -eq $defaultContainer}
                    }
                    else {
                        $pipelineObject | Measure-KubeContainers
                    }
                }
            }
            
            $measuredContainers | ForEach-Object {
                @{
                    DateTime = $apiScrapeDatetime
                    Namespace = $ns
                    PodName = $pod
                    Container = $_.Container
                    CPU = $_.cpu
                    MemoryGB = $_.memoryGB
                } -as $ViewClass
            }
        } 
    }
}