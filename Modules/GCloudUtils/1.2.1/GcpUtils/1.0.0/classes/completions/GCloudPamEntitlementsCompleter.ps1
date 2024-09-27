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
        # Note you cannot filter with Where-Object on $resultList and return that output. Something breaks. Therefore I filter on $collectAllResults
        # and move that into $resultList for the final return.
        $collectAllResults = [List[CompletionResult]]::new()

        $cacheTier, $cacheId = switch ($currentBoundParameters) {
            {$_.ContainsKey('Organization')} { 'organization', $_.Organization }
            {$_.ContainsKey('Folder')}       { 'folder', $_.Folder }
            {$_.ContainsKey('ProjectId')}    { 'project', $_.ProjectId }
        }
        if ( !$cacheTier ) {
            Write-Host "`n`nCannot tab complete on -Entitlement unless --organization, --folder, or --project have been explicitly specified first!" -Fore Red
            return $resultList
        }

        $argTier = "--${cacheTier}=$cacheId"

        $location = if ( $currentBoundParameters.Location ) { $currentBoundParameters.Location } else { 'global' }
        $argLocation = "--location=$location"

        $date = Get-Date
        
        if ( $argLocation -and $argTier ) {
            $cachedEntry = [GCloudPamEntitlementCompleter]::cachedEntitlements.$cacheTier.$cacheId | where location -eq $location
            if ( $date.AddSeconds(-30) -lt $cachedEntry.date ) {
                $cachedEntry.resultList | Where-Object { $_.ListItemText -like "$wordToComplete*"} | ForEach-Object {
                    $resultList.Add($_)
                }
                return $resultList
            }

            $gcloudArgs = @(
                'beta','pam','entitlements','list',
                '--format=json'
                $argLocation
                $argTier
            )

            $json = gcloud @gcloudArgs 2>$null | ConvertFrom-Json
            $script:j = $json
            $json | ForEach-Object {
                $completion = ($_.Name -split '/')[-1]

                $maxduration = $_.maxRequestDuration
                $roles = $_.privilegedAccess.gcpIamAccess.roleBindings.role -replace '^roles/' -join ', '
                $tooltip = "Roles: $roles | maxDur: $($maxDuration.Trim('s'))"
                $result = [CompletionResult]::new($completion, $completion, [CompletionResultType]::Text, $tooltip)
                $collectAllResults.Add($result)
                
            }

            $cachedMetaData = [PSCustomObject]@{
                date = $date
                location = $location
                resultList = $collectAllResults
            }
            [GCloudPamEntitlementCompleter]::cachedEntitlements.$cacheTier.$cacheId = $cachedMetaData
        }

        $collectAllResults | Where-Object ListItemText -like "$wordToComplete*" | ForEach-Object {
            $resultList.Add($_)
        }
        return $resultList 
    }
}

class GCloudPamEntitlementCompletionsAttribute : ArgumentCompleterAttribute, IArgumentCompleterFactory {

    [IArgumentCompleter] Create() {
        return [GCloudPamEntitlementCompleter]::new()
    }
}