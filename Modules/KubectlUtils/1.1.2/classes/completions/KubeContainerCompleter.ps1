using namespace System.Management.Automation
using namespace System.Management.Automation.Language
using namespace System.Collections
using namespace System.Collections.Generic


class KubeContainerCompleter : IArgumentCompleter {

    [IEnumerable[CompletionResult]] CompleteArgument(
        [string] $CommandName,
        [string] $parameterName,
        [string] $wordToComplete,
        [CommandAst] $commandAst,
        [IDictionary] $currentBoundParameters
    ) {
        $resultList = [List[CompletionResult]]::new()

        $ns = "--namespace=$($currentBoundParameters.Namespace)"
        $resource = switch -regex ($currentBoundParameters.Keys) {
            '^Resource$' { $currentBoundParameters.Resource }
            '^Pod(?=s|Name)' { 'pods' }
        }
        $object = switch -regex ($currentBoundParameters.Keys) {
            '^Object$' { $currentBoundParameters.Object }
            '^Pod$' { $currentBoundParameters.Pod}
            '^PodName$' { $currentBoundParameters.PodName}
        }

        $containers = & {
            if ( $resource -eq 'pods' ) {
                $podConfig = kubectl $ns get $resource $object -o json | ConvertFrom-Json
                <#$status = $podConfig.status.phase
                if ( $status -eq 'RUNNING' ) {
                    $podConfig.spec.containers.name
                }
                else {
                    $podConfig.status.containerStatuses | where ready -eq True | Select-Object -ExpandProperty Name
                }#>
                $readyStatuses = $podConfig.status.containerStatuses | where ready -eq True
                if ( $readyStatuses ) {
                    $readyStatuses
                } else {
                    $podconfig.status.initContainerStatuses | where { $_.state.running } | Select-Object -ExpandProperty name
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

        $containers | where { $_ -like "$wordToComplete*" } | foreach {
            $resultList.Add( [CompletionResult]::new($_) )
        }

        return $resultList
    }
}

class KubeContainerCompletionsAttribute : ArgumentCompleterAttribute, IArgumentCompleterFactory {

    [IArgumentCompleter] Create() {
        return [KubeContainerCompleter]::new()
    }
}