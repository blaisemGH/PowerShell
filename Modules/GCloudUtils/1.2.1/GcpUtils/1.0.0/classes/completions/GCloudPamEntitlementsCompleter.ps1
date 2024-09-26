using namespace System.Management.Automation
using namespace System.Management.Automation.Language
using namespace System.Collections
using namespace System.Collections.Generic
using namespace System.IO

class GCloudPamEntitlementCompleter : IArgumentCompleter {

    static [hashtable]$cachedEntitlements = @{
        organization = @{}
        folder = @{}
        project = @{}
    }

    [IEnumerable[CompletionResult]] CompleteArgument(
        [string] $CommandName,
        [string] $parameterName,
        [string] $wordToComplete,
        [CommandAst] $commandAst,
        [IDictionary] $currentBoundParameters
    ) {
        $resultList = [List[CompletionResult]]::new()

        $cacheTier, $cacheId = switch ($currentBoundParameters) {
            {$_.ContainsKey('Organization')} { 'organization', $_.Organization }
            {$_.ContainsKey('Folder')}       { 'folder', $_.Folder }
            {$_.ContainsKey('ProjectId')}    { 'project', $_.ProjectId }
        }
        $argTier = "--${cacheTier}=$cacheId"

        $argLocation = "--location=$($currentBoundParameters.Location)"

        $date = Get-Date
        
        if ( $argLocation -and $argTier ) {
            $cachedEntry = [GCloudPamEntitlementCompleter]::cachedEntitlements.$cacheTier.$cacheId | where location -eq $argLocation
            if ( $cachedEntry.date -gt $date.AddSeconds(-30) ) {
                return $cachedEntry.resultList | Where-Object { $_.ListText -like "$wordToComplete*"}
            }

            $gcloudArgs = @(
                'beta','pam','entitlements','list',
                '--format=json'
                $argLocation
                $argTier
            )
            gcloud @gcloudArgs 2>$null | ConvertFrom-Json | ForEach-Object {
                $completion = ($_.Name -split '/')[-1]
                
                $maxduration = $_.maxRequestDuration
                $roles = $j.privilegedAccess.gcpIamAccess.roleBindings.role -replace '^roles/' -join ', '
                $tooltip = "Roles: $roles | maxDur: $maxDuration"

                $result = [CompletionResult]::new($completion, $completion, [CompletionResultType]::Text, $tooltip)
                $resultList.Add($result)
            }

            $cachedMetaData = [PSCustomObject]@{
                date = $date
                location = $argLocation
                resultList = $resultList
            }
            [GCloudPamEntitlementCompleter]::cachedEntitlements.$cacheTier.$cacheId = $cachedMetaData
        }

        return $resultList | Where-Object { $_.ListText -like "$wordToComplete*"}
    }
}

class GCloudPamEntitlementCompletionsAttribute : ArgumentCompleterAttribute, IArgumentCompleterFactory {

    [IArgumentCompleter] Create() {
        return [GCloudPamEntitlementCompleter]::new()
    }
}