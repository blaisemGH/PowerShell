using namespace System.Collections
using namespace System.Collections.Generic
using namespace System.Management.Automation
using namespace System.Management.Automation.Language

class KubeResourceCompleter : IArgumentCompleter {

    [IEnumerable[CompletionResult]] CompleteArgument(
        [string] $CommandName,
        [string] $parameterName,
        [string] $wordToComplete,
        [CommandAst] $commandAst,
        [IDictionary] $currentBoundParameters
    ) {
        $command = $currentBoundParameters.Command

        $resourceMatches = [Kube]::FullApiResources | where {
            (
                $_.SHORTNAME -match "$wordToComplete*" -or
                ($_.NAME + '.' + $_.APIVERSION) -match "$wordToComplete*"
            ) -and
            $_.VERBS -contains $command
        } | Select-Object NAME, APIVERSION, DEFAULTAPIVERSION | Group-Object NAME

        return $(
            foreach ($item in $resourceMatches) {
                if ($item.Count -gt 1) {
                    $default = $item.Group | Where DEFAULTAPIVERSION
                    if ( $default ) {
                        [CompletionResult]::new($default.NAME + '.' + $default.DEFAULTAPIVERSION)
                    }

                    [array]$kubeDefault = $item.Group | Where { !$_.APIVERSION }
                    if ( $kubeDefault -and $kubedefault.Count -eq 1) {
                        [CompletionResult]::new($kubeDefault.Name)
                    }

                    foreach ( $group in $item.Group ) {
                        [CompletionResult]::new($group.NAME + '.' + $group.APIVERSION)
                    }
                }

                if ( $wordToComplete -match '\.' ) {
                    [CompletionResult]::new($item.NAME + '.' + $item.APIVERSION)
                }

                [CompletionResult]::new($item.NAME)
            }
        )

        #$resultList = [List[CompletionResult]]::new()
        #$resultList.Add([CompletionResult]::new($i.ToString()))
        
        #return $resultList
    }
}

class KubeResourceCompletionsAttribute : ArgumentCompleterAttribute, IArgumentCompleterFactory {

    [IArgumentCompleter] Create() {
        return [KubeResourceCompleter]::new()
    }
}