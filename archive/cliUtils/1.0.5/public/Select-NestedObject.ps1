using namespace System.Collections.Generic
using namespace System.Management.Automation

class PSObjectSelector {
    [Hashtable]$IntermediateSelectResults = @{}

    PSObjectSelector ([PSCustomObject]$inputObject) {
        $this.IntermediateSelectResults.Add('.', $inputObject)
    }

    [void]Set_NestedObjectResults([string]$delimiter, [string[]]$searchSegments){
        $noRegexDelimiter = [Regex]::Escape($delimiter)
        # Each instance of a wildcard needs to be handled separately, hence a foreach loop through each segment partitioned by a wildcard.
        foreach ( $segment in $searchSegments ) {
            if ( !$segment ) {
                continue
            }
            $cleanSegment = ($segment -split ('\s*' + $noRegexDelimiter + '\s*') | Where {$_}) -join $delimiter
            $splitNodePath = $cleanSegment -split "(?<!\*)$noRegexDelimiter", 2

            # Each segment loop is liable to return multiple results. The remaining nodepath should be applied to each result individually.
            foreach ($kvPair in $this.IntermediateSelectResults.Clone().GetEnumerator()) {
                $intermediateResults =  & {
                    if ( $splitNodePath[0] -and $splitNodePath[0] -ne '*') {
                        $this.Resolve_Wildcard($kvPair.Value, $splitNodePath[0])
                    } else {
                        $this.Resolve_Wildcard($kvPair.Value)
                    }
                }
                
                # Once the wildcard has been expanded, there could be remaining nodes in the input nodepath. Each result should append this.
                foreach ($result in $intermediateResults) {
                    $completeIntermediateSelection = & {
                        if ( $splitNodePath[1] ) {
                            $this.Select_RemainingPropertyPath($result.Value, $splitNodePath[1], $noRegexDelimiter)
                        } else {
                            $result.Value
                        }
                    }
                    
                    $iteratedNodePath = ($kvPair.Key + $result.NodePath + $splitNodePath[1] | 
                        Where-Object {$_}
                    ) -join '.' | ForEach-Object TrimStart('.') 
                    
                    # Remove the previous entry and add the updated object as each segment is parsed.
                    $this.IntermediateSelectResults.Remove($kvPair.Key)
                    if ( $this.IntermediateSelectResults.ContainsKey($iteratedNodePath) ) {
                        $this.IntermediateSelectResults.$iteratedNodePath = @($this.IntermediateSelectResults.$iteratedNodePath) + $completeIntermediateSelection
                    } else {
                        $this.IntermediateSelectResults.Add($iteratedNodePath, $completeIntermediateSelection)
                    }
                }
            }
        }
    }

    [SearchObjectDTO[]] Resolve_Wildcard([PSCustomObject]$inputObject){
        return Search-ObjectProperties -InputObject $inputObject
    }
    [SearchObjectDTO[]] Resolve_Wildcard([PSCustomObject]$inputObject, [string]$node){
        return Search-ObjectProperties -InputObject $inputObject -PropertiesToFind ($node -replace '^\*\.')
    }
    [PSCustomObject] Select_RemainingPropertyPath ([PSCustomObject]$inputObject, [string]$propertyNodes, [string]$noRegexDelimiter) {
        $selectExpression = '($inputObject)'
        # idea: In the below -split, there is no means to escape literal delimiters, e.g., "spec.'a.prop'.'b.prop'" should only split on the 1st and 3rd dots.
        # As a workaround, you can rewrite it with a different delimiter, e.g., "spec/a.prop/b.prop"
        # However, what if the string had both a / and a .? What other delimiter do you use? What if it is also included somewhere in the string?
        # The universal solution would be to enable escaping delimiters. I don't know how to do this.
        # A simple \ is insufficient as there may be a field with a \ character, and for quote-wrapping I can't get a working regex.
        ForEach ($node in ($PropertyNodes -split ("\s*$noRegexDelimiter\s*") | Where {$_})) {
            $selectExpression += ".'$node'"
        }
        return Invoke-Expression $selectExpression
    }
}

function Select-NestedObject {
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object[]]$InputObject,

        [Parameter(Position=0, ValueFromRemainingArguments)]
        [string[]]$PropertyNodes,

        [Alias('s','sep')]
        [ValidateScript({
            if ($_ -match '\*') {throw '* is reserved for wildcards and cannot be input for this parameter.'} else { $true }
        })]
        [string]$NodeSeparator,
        [switch]$ExpandProperties
    )
    begin {
        $joinedNodes = $PropertyNodes -join ' '
        $checkIfDelimiter = ($joinedNodes -replace '\*' -replace '[\w$]' -replace '^\s+$', ' ' | ForEach Trim('''"'))[0]
        $delimiter = & {
            if ($NodeSeparator ) {
                $NodeSeparator
            }
            elseif ($checkIfDelimiter) {
                $checkIfDelimiter
            }
            else { '.' }
        }
        $noRegexDelimiter = [Regex]::Escape($delimiter)

        [string[]]$searchSegments = & {
            # Parse the input PropertyNodes, specifically to handle any * characters as wildcards. No * means only 1 segment.
            # Note that the regex pattern ((?<='\S*)$target(?=\S*'))|((?<=""\S*)$target(?=\S*"")) is a means to ignore $target when it's quoted.
            #$joinedNodes -replace
                # Replace delimiter with a ., so I have a consistent delimiter going forward.
                #"((?<='\S*)$noRegexDelimiter(?=\S*'))|((?<=""\S*)$noRegexDelimiter(?=\S*""))", '.' -replac
                $joinedNodes -replace # replace quoted wildcards with a unicode placeholder
                '((?<=''\S*)[*](?=\S*''))|((?<="\S*)[*](?=\S*"))', [char]0x2561 -split
                "([*][^*]*)(?![$noRegexDelimiter])" | # Split on wildcards
                foreach TrimEnd('.') | # The split leaves trailing dots. Trim these.
                foreach replace([char]0x2561, '*') | # restore the unicode placeholder to an asterisk
                where {$_} # The split returns empty elements with every match. Remove these.
        }
    }
    process {
        foreach ($object in $InputObject) { 
            $PSObjectSelector = [PSObjectSelector]::new($object)
            $PSObjectSelector.Set_NestedObjectResults($delimiter, $searchSegments)
            
            if ( !$ExpandProperties ) {
                $PSObjectSelector.IntermediateSelectResults.Values
            } else {
                $PSObjectSelector.IntermediateSelectResults.GetEnumerator() | ForEach-Object { 
                    if ( $_.Value -is [ValueType] ) { $_.Value } else { [string[]]$_.Value }
                }
            }
        }
    }
}

<#
function Find-NestedObject {
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object]$InputObject,

        [Parameter(Position=0, ValueFromRemainingArguments)]
        [string[]]$PropertyNodes
    )
    begin {
        $selectExpression = '($InputObject)'
        ForEach ($node in ($PropertyNodes -split ('\s*\.\s*') | Where {$_})) {
            $selectExpression += ".'$node'"
        }
    }
    process {
        Invoke-Expression $selectExpression
    }
}
#>