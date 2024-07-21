using namespace System.Management.Automation
using namespace System.Management.Automation.Language
using namespace System.Collections
using namespace System.Collections.Generic

class KubeMappedContextsCompleter : IArgumentCompleter {

    [IEnumerable[CompletionResult]] CompleteArgument(
        [string] $CommandName,
        [string] $parameterName,
        [string] $wordToComplete,
        [CommandAst] $commandAst,
        [IDictionary] $currentBoundParameters
    ) {
        $resultList = [List[CompletionResult]]::new()
        #return (
            [Kube]::MappedContexts.Keys | where { [string]$_ -match "$wordToComplete*" } | foreach {
                $resultList.Add([CompletionResult]::new([string]$_))
            }
        return $resultList
    }
}

class KubeMappedContextsCompletionsAttribute : ArgumentCompleterAttribute, IArgumentCompleterFactory {

    [IArgumentCompleter] Create() {
        return [KubeMappedContextsCompleter]::new()
    }
}