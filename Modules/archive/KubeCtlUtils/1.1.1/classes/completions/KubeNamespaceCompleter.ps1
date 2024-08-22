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
        return (
            ((kubectl get namespaces -o name) -split '/')[1] + '-A' + '--all-namespaces' | foreach {
                [CompletionResult]::new($_)
            }
        )
    }
}

class KubeNamespaceCompletionsAttribute : ArgumentCompleterAttribute, IArgumentCompleterFactory {

    [IArgumentCompleter] Create() {
        return [KubeNamespaceCompleter]::new()
    }
}