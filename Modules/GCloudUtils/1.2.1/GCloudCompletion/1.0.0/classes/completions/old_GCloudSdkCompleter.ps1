using namespace System.Management.Automation
using namespace System.Management.Automation.Language
using namespace System.Collections
using namespace System.Collections.Generic

class GCloudSdkCompleter : IArgumentCompleter {
    static [string]$CompletionFilepath
    static [hashtable]$CompletionTree
    static [string]$gcloudDotPs1Path = (Get-Command gcloud.ps1 | Select-Object -ExpandProperty Source)

    [IEnumerable[CompletionResult]] CompleteArgument(
        [string] $commandName,
        [string] $parameterName,
        [string] $wordToComplete,
        [CommandAst] $commandAst,
        [IDictionary] $currentBoundParameters
    ) {
        $resultSet = [HashSet[CompletionResult]]::new()

        # Lazy load the completion dictionary. It should only need to be loaded once per session.
        if ( ![GCloudSdkCompleter]::CompletionTree ) {
            [GCloudSdkCompleter]::ImportCompletionTree()
        }
        $currentCliTreeLevel = [GCloudSdkCompleter]::CompletionTree.Clone() # Will be changing $currentCliTreeLevel, so need a clone to not corrupt the cache.

        [HashSet[string]]$inputGcloudArgs = $commandAst.CommandElements | Select-Object -Skip 1
        [Queue[string]]$gcloudTokens = $inputGcloudArgs
        
        # Compare cursor position to identify if it's a new token.
        $isStartingNewToken = ($commandAst.parent.parent.parent.Extent.Text -replace '^\s+').Length -gt ($commandAst.CommandElements -join ' ').Length

        $token = $null
        $includeSetPropertyEnums = $null
        while ( $gcloudTokens.Count -gt 0 ) {

            # If it's a section/property token but not the last token, then skip it. Not interesting.
            if ( $gcloudTokens.Count -gt 1 -and $gcloudTokens.Peek() -match '/' ) {
                [void]$gcloudTokens.Dequeue()
                continue
            }

            # If it's a repeat token or a flag, skip it. Repeat is bad and a flag is not relevant for the dictionary lookup below.
            if ( $token -eq $gcloudTokens.Peek() -or $gcloudTokens.Peek() -match '^--' ) {
                [void]$gcloudTokens.Dequeue()
                continue
            }

            $token = $gcloudTokens.Dequeue()

            # If it's part of a section/property completion, then stop the loop so it can be parsed differently below.
            if ( $token -match '/' ) {
                break
            }

            # If the token is in the completion dictionary, then open it inside the dictionary to continue with the completions.
            if ( $currentCliTreeLevel -is [Hashtable] -and $currentCliTreeLevel.ContainsKey($token) ) {
                $currentCliTreeLevel = $currentCliTreeLevel.$token
            }

            # for gcloud config set, there are enum values on the properties. I need to record that here for later to complete the property enums.
            if ( $token -eq 'set' ) {
                $section, $property = $gcloudTokens.Peek() -split '/'
                if ($currentCliTreeLevel."$section/".$property ) {
                    $includeSetPropertyEnums = $gcloudTokens.Peek()
                }
            }
        }

        $completionArgs = & {
            # Complete the property of a section, e.g., core/proj completes to core/project.
            if ( $token -match '/' ) {
                $section, $property = $token -split '/'

                [string[]]$propertyValues = $currentCliTreeLevel."$section/".Keys |
                    Where-Object { [string]$_ -like "$property*" } |
                    ForEach-Object { "$section/$_" } | 
                    Sort-Object
                
                # if, following a section/property token, you are starting a new token or completing a flag token, then add all flags
                if ( $isStartingNewToken -or $wordToComplete -match '^-') {
                    $propertyValues + ( $currentCliTreeLevel.Keys | Where { [string]$_ -like "$wordToComplete*" -and $_ -match '^--'} | Sort-Object )
                } else {
                    $propertyValues
                }
            
            
            <#
                Future code maybe if I ever have flag completions, then I will need to include a way to account for --flag=<flag completion value>
                Code not finished after flagName
            } elseif ( $wordToComplete -match '^-.*=' ) {
                $flagName = $wordToComplete -replace '=.*'
                $flagValue = '?'
                $currentCliTreeLevel.Keys | Where { ([string]$_ + '=' + $flagValue) -like "$wordToComplete*" } This is wrong still.
                #>
            } else {
                # Get all commands and flags if I am not inside a section/property token. Note this also completes the section/ portion, just not the property.
                $currentCliTreeLevel.Keys | Where { [string]$_ -like "$wordToComplete*" }
            }
        }

        # Need to run the if using a count, because I want completionArgs only if there is no matching element with '/'.
        # -notmatch is naive, as it will be treated as true by returning any inputGcloudarg that doesn't contain a /.
        $commands = if ( ! ($inputGcloudArgs -match '/').Count ) {
            $completionArgs | Where { $_ -notmatch '^--' } | Sort-Object
        } elseif ( $token -match '/' -and !$isStartingNewToken ) { # If completing a section/property, include completionArgs as it contains the completed section/property.
            $completionArgs | Sort-Object
        }
        
        # Include flags
        $flags = $completionArgs | Where { $_ -match '^--' } | Sort-Object

        # Include Property enums if there was a token somewhere in the ast that contained a /, indicating property enums might be relevant.
        [string[]]$addPropertyEnums = & {
            if ( $includeSetPropertyEnums ) {
                $section, $property = $includeSetPropertyEnums -split '/'
                [HashSet[String]]$propertyEnumValues = $currentCliTreeLevel."$section/".$property | Where {
                    $_ -like "$wordToComplete*" 
                } | Sort-Object

                # Don't include any property enums if one of them has been used somewhere already in the ast.
                if ( $propertyEnumValues -and ! $propertyEnumValues.Overlaps($inputGcloudArgs) ) {
                    $propertyEnumValues
                }

            }
        }

        [string[]]$commands + $addPropertyEnums + $flags | Where { $_ -and $_ -notin $inputGcloudArgs } | ForEach {
            [void]$resultSet.Add( [CompletionResult]::new($_, $_, [CompletionResultType]::ParameterValue, $_) )
        }

        return $resultSet
    }

    static [void] ImportCompletionTree() {
        [GCloudSdkCompleter]::CompletionTree = Get-Content ([GCloudSdkCompleter]::CompletionFilepath) -raw | ConvertFrom-Json -AsHashtable
    }

    <#
    A potential 5.1 backwards-compatible version. It doesn't use -hashtable on the Import and references ps objects. Fk it though.
    [IEnumerable[CompletionResult]] CompleteArgument(
        [string] $CommandName,
        [string] $parameterName,
        [string] $wordToComplete,
        [CommandAst] $commandAst,
        [IDictionary] $currentBoundParameters
    ) {
        [GCloudCompletions]::ImportCompletionTree()
        
        $resultSet = [HashSet[CompletionResult]]::new()

        [Queue[string]]$gcloudTokens = $commandAst.CommandElements | Where { $_ -notmatch '^gcloud' }
        $currentCliTreeLevel = [GCloudCompletions]::CompletionTree
        
        $token = $null
        while ( $gcloudTokens.Count -gt 0 ) {
            $token = $gcloudTokens.Dequeue()
            if ( $currentCliTreeLevel -is [PSCustomObject] -and $currentCliTreeLevel.PSObject.Properties.Name -Contains $token) {
                $currentCliTreeLevel = $currentCliTreeLevel.$token
            }
        }

        $completionArgs = $currentCliTreeLevel.PSObject.Properties.Name | Where { $_ -like "$wordToComplete*" }
        $commands = $completionArgs | Where { $_ -notmatch '^--' } | Sort-Object
        $flags = $completionArgs | Where { $_ -match '^--' } | Sort-Object
        $commands + $flags | ForEach {
            [void]$resultSet.Add( [CompletionResult]::new($_, $_, [CompletionResultType]::ParameterValue, $_) )
        }
        
        return $resultSet
    }

    static [void] ImportCompletionTree() {
        [GCloudCompletions]::CompletionTree = Get-Content ([GCloudCompletions]::CompletionFilepath) | ConvertFrom-Json
    }
#>
}

class GCloudSdkCompletionsAttribute : ArgumentCompleterAttribute, IArgumentCompleterFactory {

    [IArgumentCompleter] Create() {
        return [GCloudSdkCompleter]::new()
    }
}