﻿using namespace System.Management.Automation
using namespace System.Management.Automation.Language
using namespace System.Collections
using namespace System.Collections.Generic

class GcpProjectCacheInFSCompleter : IArgumentCompleter {

    [IEnumerable[CompletionResult]] CompleteArgument(
        [string] $CommandName,
        [string] $parameterName,
        [string] $wordToComplete,
        [CommandAst] $commandAst,
        [IDictionary] $currentBoundParameters
    ) {
        $resultList = [List[CompletionResult]]::new()

        Get-ChildItem ([Gcp]::ProjectRoot) -Recurse -Name -File | Where-Object {
            (Split-Path $_ -Leaf) -like "$wordToComplete*" -or
            (Split-Path $_ -Parent) -like "$wordToComplete*"
        } |
            ForEach-Object {
                $completion = $_ -replace '\s'
                $resultList.Add( [CompletionResult]::new($completion, $completion, [CompletionResultType]::ParameterValue, $completion) )
            }

        return $resultList
    }
}

class GcpProjectCacheInFSCompletionsAttribute : ArgumentCompleterAttribute, IArgumentCompleterFactory {

    [IArgumentCompleter] Create() {
        return [GcpProjectCacheInFSCompleter]::new()
    }
}