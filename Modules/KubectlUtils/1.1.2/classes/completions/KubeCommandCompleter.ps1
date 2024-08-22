using namespace System.Management.Automation
using namespace System.Management.Automation.Language

class KubeCommandCompleter : IArgumentCompleter {

    [IEnumerable[CompletionResult]] CompleteArgument(
        [string] $CommandName,
        [string] $parameterName,
        [string] $wordToComplete,
        [CommandAst] $commandAst,
        [IDictionary] $currentBoundParameters
    ) {
        return kubectl __complete $wordToComplete 2>$null  | Foreach {
            $command = $_ -split '\s' | Select-Object -First 1
            if ( $command -notmatch '^:') {
                [CompletionResult]::new($command)
            }
        }
    }
}

class KubeCommandCompletionsAttribute : ArgumentCompleterAttribute, IArgumentCompleterFactory {

    [IArgumentCompleter] Create() {
        return [KubeCommandCompleter]::new()
    }
}