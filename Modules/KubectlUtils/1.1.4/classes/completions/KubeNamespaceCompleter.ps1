using namespace System.Management.Automation
using namespace System.Management.Automation.Language
using namespace System.Collections
using namespace System.Collections.Generic

class KubeNamespaceCompleter : IArgumentCompleter {

    [IEnumerable[CompletionResult]] CompleteArgument(
        [string] $CommandName,
        [string] $parameterName,
        [string] $wordToComplete,
        [CommandAst] $commandAst,
        [IDictionary] $currentBoundParameters
    ) {
        $resultList = [List[CompletionResult]]::new()
        ((kubectl get namespaces -o name) -replace '[^\/]+/') + '-A' + '--all-namespaces' |
            Where-Object { $_ -like "*$wordToComplete*" } |
            foreach {
                $resultList.Add([CompletionResult]::new($_))
        }
        return $resultList
    }
}

class KubeNamespaceCompletionsAttribute : ArgumentCompleterAttribute, IArgumentCompleterFactory {

    [IArgumentCompleter] Create() {
        return [KubeNamespaceCompleter]::new()
    }
}

class KubeSingleNamespaceCompleter : IArgumentCompleter {

    [IEnumerable[CompletionResult]] CompleteArgument(
        [string] $CommandName,
        [string] $parameterName,
        [string] $wordToComplete,
        [CommandAst] $commandAst,
        [IDictionary] $currentBoundParameters
    ) {
        $resultList = [List[CompletionResult]]::new()
        ((kubectl get namespaces -o name) -replace '[^\/]+/') |
            Where-Object { $_ -like "*$wordToComplete*" } |
            foreach {
                $resultList.Add([CompletionResult]::new($_))
        }
        return $resultList
    }
}

class KubeSingleNamespaceCompletionsAttribute : ArgumentCompleterAttribute, IArgumentCompleterFactory {

    [IArgumentCompleter] Create() {
        return [KubeSingleNamespaceCompleter]::new()
    }
}