using namespace System.Management.Automation
using namespace System.Management.Automation.Language
using namespace System.Collections
using namespace System.Collections.Generic

<# Debug pro tip: Set these and you can run the CompleteArgument method by directly copy pasting the code to the shell, except you must skip $resultSet
 using namespace System.Collections.Generic
 $gcloudCliInput = 'gcloud config set' # Adjust this as required
 $wordToComplete = '' # Adjust this as required
 #$ast = [System.Management.Automation.Language.Parser]::ParseInput($gcloudCliInput, [ref]$null, [ref]$null)
 $commandAst = $ast.FindAll({$args[0].GetType().Name -like 'CommandAst'}, $true)
 $cursorPosition = $gcloudCliInput.Length
#>
class GcloudCompletions {
    static [string]$CompletionFilepath
    static [hashtable]$CompletionTree
    static [string]$gcloudDotPs1Path = (Get-Command gcloud.ps1 | Select-Object -ExpandProperty Source)
    static [version]$GcloudVersion = (Get-Command gcloud.ps1 | Select-Object -ExpandProperty Source | Split-Path -Parent | Split-Path -Parent | Get-ChildItem | where name -eq VERSION | Get-Content -Raw)

    [IEnumerable[CompletionResult]] GetCompletions(
        [string] $wordToComplete,
        [CommandAst] $commandAst,
        [int]$cursorPosition
    ) {
        $resultSet = [HashSet[CompletionResult]]::new()

        # Lazy load the completion dictionary. It should only need to be loaded once per session.
        if ( ![GcloudCompletions]::CompletionTree -or ![GcloudCompletions]::CompletionTree.Keys.Count ) {
            [GcloudCompletions]::ImportCompletionTree()
        }
        
        $currentCliTreeLevel = [GcloudCompletions]::CompletionTree.Clone() # Will be changing $currentCliTreeLevel, so need a clone to not corrupt the cache.
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
                        ForEach-Object { ($allFlags.$_ -and $allFlags.$_ -notin 'value','dynamic') ? "$_=" : $_ } |
                        Sort-Object
                }
                
            # If not completing a preceding flag, then just return all available flags. If there is an enum, suggest it by appending =
            } else {
                $allFlags.Keys | 
                    Where { $_ -like "$wordToComplete*" -and $_ -notin $alreadyUsedFlags } |
                    ForEach-Object { ($allFlags.$_ -and $allFlags.$_ -notin 'value','dynamic') ? "$_=" : $_ } |
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

    static [void] ImportCompletionTree() {
        $cachedCompletionFile = [GcloudCompletions]::GcloudVersion.ToString() + '_' + (Split-Path ([GcloudCompletions]::CompletionFilepath) -Leaf )
        $completionCacheFilepath = Join-Path ([GCloud]::LocalCache) completions $cachedCompletionFile

        if ( !(Test-Path $completionCacheFilepath) ) {
            [GcloudCompletions]::NewCompletionCacheFile($completionCacheFilepath)
        }

        [GcloudCompletions]::CompletionTree = Get-Content $completionCacheFilepath -Raw | ConvertFrom-Json -AsHashtable
        
        $configPropertyCompletions = [GcloudCompletionsPropertiesBuilder]::new( (gcloud topic configurations) )
        
        $propertyCompletions = $configPropertyCompletions.GetConfigPropertyCompletions()
        $pyCompletionTree = [GcloudCompletions]::CompletionTree.Clone()
        
        foreach ($configCommand in $pyCompletionTree.commands.config.commands.Keys ){
            foreach ( $kvpair in $propertyCompletions.GetEnumerator() ) {
                [GcloudCompletions]::CompletionTree.commands.config.commands.$configCommand.commands.Add( $kvPair.Key, $kvPair.Value)
            }
        }
    }

    static [void] NewCompletionCacheFile([string]$completionCacheFilepath) {
        $completionCacheDir = Split-Path $completionCacheFilepath -Parent
        $gcloudCompletionFile = Split-Path ([GcloudCompletions]::CompletionFilepath) -Leaf

        $existingLocalCompletionFileVersions = Get-ChildItem $completionCacheDir -Filter "*$gcloudCompletionFile.json" | Sort-Object Name | ForEach-Object {
            $_.Name -split '_' | Select-Object -First 1
        }

        if ( $existingLocalCompletionFileVersions -notcontains [GcloudCompletions]::GcloudVersion.ToString() ) {

            '{' + (Get-Content ([GcloudCompletions]::CompletionFilepath) | Select-Object -skip 4) |
                ConvertFrom-Json |
                ConvertTo-Json -Compress -Depth 100 |
                Set-Content $completionCacheFilepath
        }
    }
}

class GcloudCompletionsPropertiesBuilder {
    [string[]]$RelevantHelpMenuText
    
    GcloudCompletionsPropertiesBuilder([string[]]$helpMenuToParse) {
        $relevantHelpMenuSection = $helpMenuToParse -join "`n" | Select-String '(?sm)(?<=^AVAILABLE PROPERTIES\n).*\n(?=^NOTES)'
        $this.RelevantHelpMenuText = $relevantHelpMenuSection -split '\n'
    }

    [hashtable] GetConfigPropertyCompletions() {

        $completionDictionary = @{}

        $currentSection = $null
        $currentProperty = $null
        foreach ($line in $this.RelevantHelpMenuText ) {
            switch -regex ($line) {
                '^\s{5}[a-zA-Z0-9]' {
                    $currentSection = $line.Trim()
                    $completionDictionary.Add("$CurrentSection/", @{})
                }
                '^\s{9}[a-zA-Z0-9]' {
                    $currentProperty = $line.Trim()
                    try {
                    $completionDictionary."$currentSection/".Add($currentProperty, [HashSet[string]]::new())
                    } catch {
                        $completionDictionary | out-string
                        $currentSection
                        $currentProperty }
                }
                '^\s{10,}\+ [a-zA-Z0-9_'']+ -' {
                    $enumValue = ($line -split ' - ' | Select-Object -first 1).Trim("' +")
                    [void]$completionDictionary."$currentSection/".$currentProperty.Add($enumValue)
                }
                '^\s{10,}If True,? ' {
                    [void]$completionDictionary."$currentSection/".$currentProperty.Add('True')
                    [void]$completionDictionary."$currentSection/".$currentProperty.Add('False')
                }
            }
        }

        return $completionDictionary
    }
}
