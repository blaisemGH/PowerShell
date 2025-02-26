using namespace System.Management.Automation
using namespace System.Management.Automation.Language
using namespace System.Collections
using namespace System.Collections.Generic
function Register-GCloudCompletion {
    $sbGcloudCompletion = {
        param(
            $WordToComplete,
            $CommandAst,
            $CursorPosition
        )
    
        $resultSet = [HashSet[CompletionResult]]::new()
    
            # Lazy load the completion dictionary. It should only need to be loaded once per session.
            if ( ![GcloudCompletions]::CompletionTree -or ![GcloudCompletions]::CompletionTree.Keys.Count ) {
                [GcloudCompletions]::ImportCompletionTree()
            }
        
            $currentCliTreeLevel = [GcloudCompletions]::CompletionTree.Clone() # $currentCliTreeLevel will be updated, so need a clone to not corrupt the cache.
            $globalFlags = $currentCliTreeLevel.flags
        
            [HashSet[string]]$inputGcloudArgs = $commandAst.CommandElements | Select-Object -Skip 1
            [Queue[string]]$gcloudTokens = $inputGcloudArgs
            
            # Compare cursor position to identify if it's a new token.
            $isStartingNewToken = $cursorPosition -gt $commandAst.Extent.EndOffset
        
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
                if ( $currentCliTreeLevel -is [Hashtable] -and $currentCliTreeLevel.commands.ContainsKey($token) ) {
                    $currentCliTreeLevel = $currentCliTreeLevel.commands.$token
                }
            
                # for gcloud config set, there are enum values on the properties. I need to record that here for later to complete the property enums.
                if ( $gcloudTokens.Count -gt 0 -and $token -eq 'set' ) {
                    $section, $property = $gcloudTokens.Peek() -split '/'
                    if ($currentCliTreeLevel.commands."$section/".$property ) {
                        $includeSetPropertyEnums = $gcloudTokens.Peek()
                    }
                }
            }
        
            [string[]]$completionCommands = & {
                # Complete the property of a section, e.g., core/proj completes to core/project.
                if ( $token -match '/' -and !$isStartingNewToken ) {
                    $section, $property = $token -split '/'
                
                    $currentCliTreeLevel.commands."$section/".Keys |
                        Where-Object { [string]$_ -like "$property*" } |
                        ForEach-Object { "$section/$_" } | 
                        Sort-Object
                
                # First condition is so that it fires if there are no arguments after gcloud
                # If a section/property has already appeared in the ast, then assume there cannot be any new commands.
                # To filter this, I need to run the if using a count to check if any elements match '/'.
                # -notmatch on '/' is naive, as it will be treated as true by returning any inputGcloudarg that doesn't contain a /.
                } elseif ( ! $inputGcloudArgs -or !($inputGcloudArgs -match '/').Count) {
                    $currentCliTreeLevel.commands.Keys | Where { [string]$_ -like "$wordToComplete*" } | Sort-Object
                }
            }
        
            # Include Property enums if there was a token somewhere in the ast that contained a /, indicating property enums might be relevant.
            [string[]]$addPropertyEnums = & {
                if ( $includeSetPropertyEnums ) {
                    $section, $property = $includeSetPropertyEnums -split '/'
                    [HashSet[String]]$propertyEnumValues = $currentCliTreeLevel.commands."$section/".$property | Where {
                        $_ -like "$wordToComplete*" 
                    } | Sort-Object
                
                    # Don't include any property enums if one of them has been used somewhere already in the ast.
                    if ( $propertyEnumValues -and ! $propertyEnumValues.Overlaps($inputGcloudArgs) ) {
                        $propertyEnumValues
                    }
                
                }
            }
        
            # Temp variable to identify if the previous item in the ast was a flag. This requires control flow to handle and is run below.
            $precedingFlag = & { 
                if ( $inputGcloudArgs -and $isStartingNewToken -and $inputGcloudArgs[-1] -match '^--') {
                    $inputGcloudArgs[-1]
                } elseif ($wordToComplete -match '^--.*=') {
                    $wordToComplete -split '=' | Select-Object -First 1
                }
            }
            # Get already used flags to avoid duplicating them in a later step
            [HashSet[string]]$alreadyUsedFlags = $inputGcloudArgs | where { $_ -match '^--'} | ForEach-Object { $_ -split '= ' | Select-Object -First 1 }
            
            # Need to create a new hashtable that includes the global flags and the current level's flags.
            # The current level flags take precedence via overwriting existing keys.
            $allFlags = $globalFlags.Clone()
            
            $currentCliTreeLevel.flags.GetEnumerator() | ForEach-Object {
                $key = $_.Key
                $value = $_.Value
                $allFlags.$key = $value
            }
        
            # Get all flags and/or their enum values
            [string[]]$completionFlagsAndFlagValues = & {
            
                if ( $precedingFlag ) {
                    [string[]]$flagValues = switch ($allFlags.$precedingFlag) {
                        { $_ -in 'bool','dynamic','value'} { '' }
                        DEFAULT { $_ }
                    }
                
                    # If completing a flag with =, then append the possible enum values. Empty enums should return nothing and leave the user to manually input.
                    if ( $wordToComplete -match '^--.*=' ) {
                        $flagValues |
                            ForEach-Object { "$precedingFlag=$_" } |
                            Where-Object { $_ -like "$wordToComplete*" } |
                            Sort-Object
                    
                    # If not completing with = but there are enums, then provide these.
                    } elseif ($flagValues) {
                        $flagValues | Where { $_ -like "$wordToComplete*" } | Sort-Object
                    
                    # If not completing with = and there are no enums, then just return all available flags. If there is an enum, suggest it by appending =
                    } else {
                        $allFlags.Keys | 
                            Where { $_ -like "$wordToComplete*" -and $_ -notin $alreadyUsedFlags } |
                            ForEach-Object { ($allFlags.$_ -and $allFlags.$_ -notin 'bool','value','dynamic') ? "$_=" : $_ } |
                            Sort-Object
                    }
                    
                # If not completing a preceding flag, then just return all available flags. If there is an enum, suggest it by appending =
                } else {
                    $allFlags.Keys | 
                        Where { $_ -like "$wordToComplete*" -and $_ -notin $alreadyUsedFlags } |
                        ForEach-Object { ($allFlags.$_ -and $allFlags.$_ -notin 'bool','value','dynamic') ? "$_=" : $_ } |
                        Sort-Object
                }
            }
            
            [string[]]$completionCommands + $addPropertyEnums + $completionFlagsAndFlagValues |
                Where { $_ -and $_ -notin $inputGcloudArgs } |
                ForEach {
                    [void]$resultSet.Add( [CompletionResult]::new($_, $_, [CompletionResultType]::ParameterValue, $_) )
                }
            
            return $resultSet
    }

    Register-ArgumentCompleter -Native -CommandName gcloud -ScriptBlock $sbGcloudCompletion
}
<#function Register-GCloudCompletion {
    $gcloudCompletion = {
        param($wordToComplete, $commandAst, $commandCharPosition)
        $argTokens = $commandAst.CommandElements.Extent.Text | where { $_ -notmatch '^-' }
        $ht = [GCloud]::CompletionTree.Clone()
        $gcloudAllFlags = $ht.gcloudAllFlags | Sort-Object
        $ht.Remove('gcloudAllFlags')

        # step through completion possibilities for each token.
        if ( $argTokens.Count -gt 1 ) {
            foreach ( $token in $argTokens ){
                if ( $token -eq 'gcloud' ) { continue }
                if ( $ht.ContainsKey($token) ) { #-and !$flagIsCommandWithProperties...
                    if ( $ht[$token].ContainsKey('commandProperties') ) {
                        $ht = $ht[$token].commandProperties
                    }
                    else {
                        $ht = $ht[$token]
                    }
                }
            }
        }
            
        # Handle the case where the last token is a subarg. This requires a different completion logic.
        if ( $argTokens[-1] -match '=' ) {
            $key = ($argTokens[-1] -split '=')[0] + '='
            $value = $ht.$key
            $outCompletionStrings = switch ($value) {
                { $_ -is [IList] } {
                    $value
                }
                { $_ -is [IDictionary] } {
                    $splitSubArgs = $completionStrings[0] -split '=',2
                    if ( $splitSubArgs.Count -gt 1) {
                        [string[]]$subTokens = $splitSubArgs[-1] -split ','
                        $lastSubToken = $subTokens[-1]

                        # if --arg=sub1=<unfinished value> or --arg=sub1=
                        if ( $lastSubToken -match '=' ) {
                            [string[]]$splitLastSubToken = $lastSubToken -split '='
                            $lastSubValue = $splitLastSubToken[1]
                            $value.Values | where { $_ -like "$lastSubValue*" }
                          # if --arg=sub1=x,sub2=y or --arg=su
                        } else {
                            $lastSubKey = $lastSubToken[0]
                            [string[]]$alreadyUsedSubKeys = $subtokens | foreach {
                                if ($_ -match '=') {
                                    ($_ -split '=')[0]
                                }
                            }
                            $value.Keys | where { $_ -notin $alreadyUsedSubKeys -and $_ -like "$lastSubKey*" }
                        }
                        # if --arg=
                    } else {
                        $value.Keys
                    }
                }
            }           
            return $outCompletionStrings | Sort-Object -Unique
        }
        else {
            $gcloudAllFlags = if ( $ht.gcloudAllowedAllFlags ) {
                $ht.gcloudAllowedAllFlags
            } else { @() }

            return [string[]]($ht.Keys | Where-Object { $_ -like "$wordToComplete*" -and $_ -notin 'gcloudAllowedAllFlags', 'commandProperties' } | Sort-Object -Unique) + ($gcloudAllFlags | Where-Object { $_ -notin $argTokens -and $_ -in $flags })
        }
    }

    Register-ArgumentCompleter -CommandName gcloud -ScriptBlock $gcloudCompletion -Native
}#>