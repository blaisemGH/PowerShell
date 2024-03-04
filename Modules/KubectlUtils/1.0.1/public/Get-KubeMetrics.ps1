using namespace System.Collections.Generic

Function Get-KubeMetrics {
    [CmdletBinding(DefaultParameterSetName = 'defaultContainers')]
    Param(
        [Parameter(ParameterSetName = 'allContainers')]
        [alias('all')]
        [switch]$ShowAllContainers,

        [Parameter(ParameterSetName = 'defaultContainers')]
        [alias('default')]
        [switch]$ShowDefaultContainers,

        [Parameter(ParameterSetName = 'customContainers')]
        [alias('custom')]
        [switch]$ShowCustomContainers,

        [Parameter(ParameterSetName = 'noFilter')]
        [alias('full')]
        [switch]$ShowFullObject,

        [alias('prettify')]
        [switch]$FormatOutput,

        [Parameter(ValueFromRemainingArguments)]
        [ArgumentCompleter(
            {
                Param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                # If completing the first argument to a parameter, the Ast parses the token as the top-level Value to CommandElements. Subsequent arguments cause the Ast to group all tokens into the nested property Elements.
                # $paramTokens adds both possible Value locations to account for either scenario.
                $paramTokens = $commandAst.CommandElements[-1].Value + $commandAst.CommandElements[-1].Elements.Value
                $lastTokenToComplete = $paramTokens | Where { $_ } | Select-Object -Last 1
                [Kube]::Namespaces() + '--all-namespaces' | Where-Object {
                    $_ -like "$lastTokenToComplete*" -and
                    $_ -notin $paramTokens
                }
            }
        )]
        [string[]]$Namespaces = (kubectl config view --minify -o json | ConvertFrom-Json).contexts.context.namespace
    )
    
    $out = switch ($PSCmdlet.ParameterSetName) {
        allContainers { Get-AllKubeMetrics -Namespaces $Namespaces | Select-Object -ExpandProperty PodMetrics }
        defaultContainers { Get-AllKubeMetrics -Namespaces $Namespaces | Select-Object -ExpandProperty DefaultPodMetrics }
        customContainers { Get-AllKubeMetrics -Namespaces $Namespaces | Select-Object -ExpandProperty CustomPodMetrics }
        DEFAULT { Get-AllKubeMetrics -Namespaces $Namespaces }
    }
    
    if ( $FormatOutput) {
        if ( $Namespaces -Contains '-A' ) {
            Write-Output $out | Select-Object date, namespace, podname, container, threads, memorygb | Format-Table -Wrap
        }
        else {
            Write-Output $out | Select-Object date, podname, container, threads, memorygb | Format-Table -Wrap
        }
    }
    else {
        Write-Output $out
    }
}


Function Get-AllKubeMetrics {
    Param(
        [Parameter(ValueFromRemainingArguments)]
        [ArgumentCompleter(
            {
                Param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $paramTokens = $commandAst.CommandElements[-1].Value + $commandAst.CommandElements[-1].Elements.Value
                $lastTokenToComplete = $paramTokens | Where { $_ } | Select-Object -Last 1
                [Kube]::Namespaces() + '--all-namespaces' | Where-Object {
                    $_ -like "$lastTokenToComplete*" -and
                    $_ -notin $paramTokens
                }
            }
        )]
        [string[]]$Namespaces = (kubectl config view --minify -o json | ConvertFrom-Json).contexts.context.namespace
        #[string[]]$Namespaces = ( kubectl get serviceaccounts default -o jsonpath='{.metadata.namespace}' )
    )

    $filterNamespaces = @(
        if ( $Namespaces -contains '-A' ) {
            [Kube]::Namespaces()
        } else {
            $Namespaces
        }
    )

    $date = Get-Date
    $metrics = & {
        kubectl get --raw "/apis/metrics.k8s.io/v1beta1/pods" |
        ConvertFrom-Json |
        Select-Object -Exp items | 
        where {
            $_.metadata.namespace -in $filterNamespaces
        }
    }

    # calls to the api-server via kubectl provide annotations, including the default container, which is used in the defaultContainersView.
    $podKubectlConfig = if ( $filterNamespaces.count -eq 1 ) {
        kubectl -n $filterNamespaces[0] get pods -o json | ConvertFrom-Json | Select-Object -ExpandProperty items
    } else {
        kubectl get pods -A -o json | ConvertFrom-Json | Select-Object -ExpandProperty items
    }

    return (
        [PSCustomObject]@{
            Date = $date
            PodMetrics = $(
                Foreach ($ns in $filterNamespaces) {
                    $metrics | Where {
                        $_.metadata.namespace -eq $ns
                    } | ForEach-Object {
                        $_ | Measure-KubeContainers -Namespace $_.metadata.namespace -PodName $_.metadata.name
                    }
                }
            )
            DefaultPodMetrics = (
                $metrics | ForEach-Object {
                    $ns = $_.metadata.namespace
                    $pod = $_.metadata.name
                    $defaultContainer = ($podKubectlConfig | Where {
                        $_.metadata.namespace -eq $ns -and $_.metadata.name -eq $pod
                    }).metadata.annotations.'kubectl.kubernetes.io/default-container'

                    $_.containers | where {
                        $_.name -eq $defaultContainer
                    } | ForEach-Object {
                        Measure-KubeContainers -Containers $_ -Namespace $ns -PodName $pod
                    }
                }
            )
            CustomPodMetrics = (
                $metrics | ForEach-Object {
                    $ns = $_.metadata.namespace
                    $pod = $_.metadata.name
                    $_.containers | where {
                        ([HashSet[string]]$_.name).Overlaps(
                            [Kube]::relevantContainers
                        )
                    } | ForEach-Object {
                        Measure-KubeContainers -Containers $_ -Namespace $ns -PodName $pod
                    }
                }
            )
        }
    )
}