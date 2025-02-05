using namespace System.Management.Automation
using namespace System.Management.Automation.Language
using namespace System.Collections.Generic
using namespace System.Collections

class KubeServiceCompleter : IArgumentCompleter {

    [IEnumerable[CompletionResult]] CompleteArgument(
        [string] $CommandName,
        [string] $parameterName,
        [string] $wordToComplete,
        [CommandAst] $commandAst,
        [IDictionary] $currentBoundParameters
    ) {
        $resultList = [List[CompletionResult]]::new()

        $ns = if ( $currentBoundParameters.Namespace ) {
            "--namespace=$($currentBoundParameters.Namespace)"
        }
        
        (kubectl $ns get services -o name) -replace '^[^/]+/' |
            Where-Object { $_ -like "$wordToComplete*" } |
            foreach {
                $resultList.Add([CompletionResult]::new($_))
        }

        return $resultList
    }
}

class KubeServiceCompletionsAttribute : ArgumentCompleterAttribute, IArgumentCompleterFactory {

    [IArgumentCompleter] Create() {
        return [KubeServiceCompleter]::new()
    }
}