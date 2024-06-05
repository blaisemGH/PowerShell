using namespace System.Management.Automation
using namespace System.Management.Automation.Language

class KubeObjectCompleter : IArgumentCompleter {

    [IEnumerable[CompletionResult]] CompleteArgument(
        [string] $CommandName,
        [string] $parameterName,
        [string] $wordToComplete,
        [CommandAst] $commandAst,
        [IDictionary] $currentBoundParameters
    ) {
        $command = $currentBoundParameters.Command
        $ns = "--namespace=$($currentBoundParameters.Namespace)"
        $resource = $currentBoundParameters.Resource
        
        $objects = & {
            if ( $command -eq 'logs' -and !$resource ) {
                ((kubectl $ns get pods -o name) -split '/')[1]
            }
            elseif ( $command -eq 'port-forward' -and !$resource ) {
                ((kubectl $ns get services -o name) -split '/')[1]
            }
            else {
                ((kubectl $ns get $resource -o name) -split '/')[1] 
            }
        }
        
        return $objects | Foreach {
            [CompletionResult]::new($_)
        }
    }
}

class KubeObjectCompletionsAttribute : ArgumentCompleterAttribute, IArgumentCompleterFactory {

    [IArgumentCompleter] Create() {
        return [KubeObjectCompleter]::new()
    }
}