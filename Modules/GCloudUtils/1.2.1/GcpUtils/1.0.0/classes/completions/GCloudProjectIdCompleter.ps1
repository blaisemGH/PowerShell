using namespace System.Management.Automation
using namespace System.Management.Automation.Language
using namespace System.Collections
using namespace System.Collections.Generic

class GCloudProjectIdCompleter : IArgumentCompleter {

    static [psobject] $cachedProjects = [PSCustomObject]@{}

    [IEnumerable[CompletionResult]] CompleteArgument(
        [string] $CommandName,
        [string] $parameterName,
        [string] $wordToComplete,
        [CommandAst] $commandAst,
        [IDictionary] $currentBoundParameters
    ) {
        $resultList = [List[CompletionResult]]::new()
        $date = Get-Date

        if ( [GCloudProjectIdCompleter]::cachedProjects.date -is [datetime] -and 
            ([GCloudProjectIdCompleter]::cachedProjects | Where-Object date -gt $date.AddSeconds(-30))
        ) {
            return [GCloudProjectIdCompleter]::cachedProjects.resultList | Where-Object { $_.ListText -like "$wordToComplete" }
        }

        gcloud projects list --format json 2>$null | ConvertFrom-Json | Where-Object name -like "$wordToComplete*" | ForEach-Object {
            $completion = $_.projectId
            $listText = $_.Name
            $labels = $_.labels
            $labelsParsed = ($labels.psobject.properties.Name | ForEach-Object { $prop = $_; $value = $labels.$prop; "${prop}: $value"}) -join ', '
            $tooltip = "$completion/$($_.projectNumber) | parent: $($_.parent) ($labelsParsed)"
            
            $result = [CompletionResult]::new($completion, $listText, [CompletionResultType]::Text, $tooltip)
            $resultList.Add($result)
        }

        $cachedMetaData = [PSCustomObject]@{
            date = $date
            resultList = $resultList
        }
        [GCloudProjectIdCompleter]::cachedProjects = $cachedMetaData

        return $resultList
    }
}

class GCloudProjectIdCompletionsAttribute : ArgumentCompleterAttribute, IArgumentCompleterFactory {

    [IArgumentCompleter] Create() {
        return [GCloudProjectIdCompleter]::new()
    }
}