using namespace System.Management.Automation
using namespace System.Management.Automation.Language

class KubeContainerCompleter : IArgumentCompleter {

    [IEnumerable[CompletionResult]] CompleteArgument(
        [string] $CommandName,
        [string] $parameterName,
        [string] $wordToComplete,
        [CommandAst] $commandAst,
        [IDictionary] $currentBoundParameters
    ) {
        $ns = "--namespace=$($currentBoundParameters.Namespace)"
        $resource = $currentBoundParameters.Resource
        $object = $currentBoundParameters.Object
        
        $containers = & {
            if ( $resource -eq 'pods' ) {
                $podConfig = kubectl $ns get $resource $object -o json | ConvertFrom-Json
                $status = $podConfig.status.phase
                if ( $status -eq 'RUNNING' ) {
                    $podConfig.spec.containers.name
                }
                else {
                    $podConfig.status.containerStatuses | where ready -ne True | Select-Object -ExpandProperty Name
                }
            }

            elseif ( $resource -in 'deployments.apps', 'statefulsets.apps', 'replicasets.apps' ) {
                $resourceConfig = kubectl $ns get $resource $object -o json | ConvertFrom-Json
                if ( $resourceConfig.status.readyReplicas -eq $resourceConfig.status.replicas ) {
                    $resourceConfig.spec.template.spec.containers.name
                }
                elseif ( $resourceConfig.status.readyReplicas -eq 0 ) {
                    $resourceConfig.spec.template.spec.initContainers.name
                }
                else {
                    $resourceConfig.spec.template.spec.containers.name + $resourceConfig.spec.template.spec.initContainers.name
                }
            }

            elseif ( $resource -in 'daemonsets.apps' ) {
                $dsConfig = kubectl $ns get $resource $object -o json | ConvertFrom-Json
                if ( $dsConfig.status.numberReady -eq $dsConfig.status.desiredNumberScheduled ) {
                    $dsConfig.spec.template.spec.containers.name
                }
                elseif ( $ds.status.numberReady -eq 0 ) {
                    $dsConfig.spec.template.spec.initContainers.name
                }
                else {
                    $dsConfig.spec.template.spec.containers.name + $dsConfig.spec.template.spec.initContainers.name
                }
            }
        }

        return $containers | foreach {
            [CompletionResult]::new($_)
        }
    }
}

class KubeContainerCompletionsAttribute : ArgumentCompleterAttribute, IArgumentCompleterFactory {

    [IArgumentCompleter] Create() {
        return [KubeContainerCompleter]::new()
    }
}