using namespace System.Management.Automation
using namespace System.Management.Automation.Language
using namespace System.Collections
using namespace System.Collections.Generic

class GitLocalBranchCompleter : IArgumentCompleter {

    [IEnumerable[CompletionResult]] CompleteArgument(
        [string] $CommandName,
        [string] $parameterName,
        [string] $wordToComplete,
        [CommandAst] $commandAst,
        [IDictionary] $currentBoundParameters
    ) {
        
        $resultList = [List[CompletionResult]]::new()

        [string[]]@((git branch) -replace '\*' -replace '\s') |
            Where-Object {
                $_ -like "$wordToComplete*"
            } | ForEach-Object {
                $resultList.Add($_)
            }

        return $resultList
    }
}

class GitLocalBranchCompletionsAttribute : ArgumentCompleterAttribute, IArgumentCompleterFactory {

    [IArgumentCompleter] Create() {
        return [GitLocalBranchCompleter]::new()
    }
}

class GitRemoteBranchCompleter : IArgumentCompleter {

    [IEnumerable[CompletionResult]] CompleteArgument(
        [string] $CommandName,
        [string] $parameterName,
        [string] $wordToComplete,
        [CommandAst] $commandAst,
        [IDictionary] $currentBoundParameters
    ) {
        $resultList = [List[CompletionResult]]::new()
        
        [string[]](git branch -r) |
            Where-Object {
                $_ -like "$wordToComplete*"
            } |
            ForEach-Object {
                $resultList.Add($_)
            }

        return $resultList
    }
}

class GitRemoteBranchCompletionsAttribute : ArgumentCompleterAttribute, IArgumentCompleterFactory {

    [IArgumentCompleter] Create() {
        return [GitRemoteBranchCompleter]::new()
    }
}

class GitLocalCommitsCompleter : IArgumentCompleter {

    [IEnumerable[CompletionResult]] CompleteArgument(
        [string] $CommandName,
        [string] $parameterName,
        [string] $wordToComplete,
        [CommandAst] $commandAst,
        [IDictionary] $currentBoundParameters
    ) {
        $resultList = [List[CompletionResult]]::new()
        
        #$remoteRepo = git remote -v | Select-String 'fetch' | ForEach-Object { $_ -split '\s' } | Select-Object -First 1
        #$currentBranch = git branch --show-current
        
        #$resultList.Add("${remoteRepo}/$currentBranch")

        git log --pretty=format:'%H | %an | %ad | %s | %D' --date=iso | Select-Object -First 30 | ForEach-Object {
            $parts = $_ -split ' \| '
            $id = $parts[0]
            $author = ($parts[1] -split ' ')[-1]
            $date = Get-Date $parts[2] -format 'yyyy-MM-dd HH:mm:ss'
            $subject = $parts[3]
            $tags = if ( $parts[4] ) { $parts[4] }
            $tooltip = "$author | $date | $subject"
            
            [System.Management.Automation.CompletionResult]::new(
                $id,
                "$id | $tags",
                [System.Management.Automation.CompletionResultType]::Text,
                $tooltip
            )
        } | Where-Object { $_.CompletionText -like "$wordToComplete*" } | ForEach-Object {
            $resultList.Add($_)
        }

        return $resultList
    }
}

class GitLocalCommitsCompletionsAttribute : ArgumentCompleterAttribute, IArgumentCompleterFactory {

    [IArgumentCompleter] Create() {
        return [GitLocalCommitsCompleter]::new()
    }
}

class GitNewShellFilesCompleter : IArgumentCompleter {

    [IEnumerable[CompletionResult]] CompleteArgument(
        [string] $CommandName,
        [string] $parameterName,
        [string] $wordToComplete,
        [CommandAst] $commandAst,
        [IDictionary] $currentBoundParameters
    ) {
        $resultList = [List[CompletionResult]]::new()
        
        git diff --name-only | 
            Where-Object {
                $_ -match '\..{0,2}sh$' -and
                $_ -like "$wordToComplete*"
            } |
            ForEach-Object {
                $resultList.Add($_)
            }

        return $resultList
    }
}

class GitNewShellFilesCompletionsAttribute : ArgumentCompleterAttribute, IArgumentCompleterFactory {

    [IArgumentCompleter] Create() {
        return [GitNewShellFilesCompleter]::new()
    }
}