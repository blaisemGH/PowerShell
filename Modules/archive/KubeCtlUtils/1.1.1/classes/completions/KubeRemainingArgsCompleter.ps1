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
        [string]$Command = $CommandAst.CommandElements

        $Program,$Arguments = $Command -Split ' ', 2
        return kubectl __complete $wordToComplete 2>$null  | Foreach { $_ -split '\s' | Select-Object -First 1 } | where { $_ -notmatch '^:' }
    }
}

class KubeCommandCompletionsAttribute : ArgumentCompleterAttribute, IArgumentCompleterFactory {

    [IArgumentCompleter] Create() {
        return [KubeCommandCompleter]::new()
    }
}