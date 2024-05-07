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

            $lockedSegment = $this.LockQuotedNodes($segment, $noRegexDelimiter)
            # Handle any null values / consecutive delimiters / whitespace
            $cleanSegment = (
                $lockedSegment -split ('\s*' + $noRegexDelimiter + '\s*') | Where {$_}
            ) -join $delimiter
            
            $splitNodePath = $cleanSegment -split "(?<!\*)$noRegexDelimiter", 2
            $maybeWildCardNode = $splitNodePath[0]
            $noWildCardNodes = $this.UnlockQuotedNodes($splitNodePath[1], $delimiter)

            # Each segment loop is liable to return multiple results. The remaining nodepath should be applied to each result individually.
            foreach ($kvPair in $this.IntermediateSelectResults.Clone().GetEnumerator()) {
                $intermediateResults =  & {
                    if ( $maybeWildCardNode -and $maybeWildCardNode -ne '*') {
                        $this.Resolve_Wildcard($kvPair.Value, $maybeWildCardNode)
                    } else {
                        $this.Resolve_Wildcard($kvPair.Value)
                    }
                }
                
                # Once the wildcard has been expanded, there could be remaining nodes in the input nodepath. Each result should append this.
                foreach ($result in $intermediateResults) {
                    $completeIntermediateSelection = & {
                        if ( $noWildCardNodes ) {
                            $this.Select_RemainingPropertyPath($result.Value, $splitNodePath[1], $delimiter, $noRegexDelimiter)
                        } else {
                            $result.Value
                        }
                    }
                    
                    $iteratedNodePath = ($kvPair.Key + $result.NodePath + $noWildCardNodes | 
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
    [PSCustomObject] Select_RemainingPropertyPath ([PSCustomObject]$inputObject, [string]$propertyNodes, [string]$delimiter, [string]$noRegexDelimiter) {
        $selectExpression = '($inputObject)'

        $protectQuotedNodes = $this.LockQuotedNodes($propertyNodes, $noRegexDelimiter )
        
        
        ForEach ($node in ($protectQuotedNodes -split ("\s*$noRegexDelimiter\s*") | Where {$_})) {
            $nodeWithDeactivatedQuotes = $node -replace '^"(.*)"$', '$1' -replace "^'(.*)'$", '$1' -replace "'", "''"
            $selectExpression += ".'$nodeWithDeactivatedQuotes'"
        }
        $finalNodePath = $this.UnlockQuotedNodes($selectExpression, $delimiter)
        return Invoke-Expression $finalNodePath
    }
    [string] LockQuotedNodes([string]$nodes, [string]$noRegexDelimiter) {
        return $nodes -replace
            "('[^'.]+)$noRegexDelimiter([^'.]+')", ('$1' + ([string][char]0x2561 * 3) + '$2') -replace
            "('[^"".]+)$noRegexDelimiter([^"".]+')", ('$1' + ([string][char]0x2561 * 3) + '$2')
    }
    [string] UnlockQuotedNodes([string]$nodes, $delimiter) {
        return $nodes -replace ([string][char]0x2561 * 3), $delimiter
    }
}

function Select-NestedObject {
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object[]]$InputObject,

        [Alias('NodePath')]
        [Parameter(Position=0, ValueFromPipelineByPropertyName, ValueFromRemainingArguments)]
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
                $PSObjectSelector.IntermediateSelectResults.Values | Write-Output
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