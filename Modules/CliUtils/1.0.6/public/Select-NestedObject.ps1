using namespace System.Collections.Generic
using namespace System.Management.Automation

class PSObjectSelector {
    [Hashtable]$IntermediateSelectResults = @{}

    PSObjectSelector ([PSCustomObject]$inputObject) {
        $this.IntermediateSelectResults.Add('.', $inputObject)
    }

    [void]SetNestedObjectResults([string]$delimiter, [string[]]$searchSegments){
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
            $nonWildCardNodes = $this.UnlockQuotedNodes($splitNodePath[1], $delimiter)

            # Each segment loop is liable to return multiple results. The remaining nodepath should be applied to each result individually.
            foreach ($kvPair in $this.IntermediateSelectResults.Clone().GetEnumerator()) {
                # Resolves the first node, resolving out a possible wildcard.
                $intermediateResults = $this.ResolveNestedObject($kvPair.Value, $maybeWildCardNode)
                
                # Once the first node has been expanded, there could be remaining nodes in the input nodepath. Each result should append this.
                foreach ($result in $intermediateResults) {
                    $completeIntermediateSelection = & {
                        if ( $nonWildCardNodes ) {
                            $this.SelectRemainingPropertyPath($result.Value, $splitNodePath[1], $delimiter, $noRegexDelimiter)
                        } else {
                            $result.Value
                        }
                    }
                    
                    $iteratedNodePath = (
                        $kvPair.Key + $result.NodePath + $nonWildCardNodes | Where-Object {$_}
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

    [SearchObjectDTO[]] ResolveNestedObject([PSCustomObject]$inputObject, [string]$node){
        if ( $node -match '^\*.+' ) {
            return Search-ObjectProperties -InputObject $inputObject -PropertiesToFind ($node -replace '^\*\.')    
        }
        
        $index = -1
        
        return $(
            foreach ( $object in $inputObject.$node) {
                [SearchObjectDTOFull]@{
                    Idx = ($index += 1)
                    Value = $object
                    NodePath = $node
                }
            }
        )
    }

    [PSCustomObject] SelectRemainingPropertyPath ([PSCustomObject]$inputObject, [string]$propertyNodes, [string]$delimiter, [string]$noRegexDelimiter) {
        $selectExpression = '($inputObject)'

        $protectQuotedNodes = $this.LockQuotedNodes($propertyNodes, $noRegexDelimiter )
        
        
        ForEach ($node in ($protectQuotedNodes -split ("\s*$noRegexDelimiter\s*") | Where {$_})) {
            $nodeWithDeactivatedQuotes = $node -replace '^"(.*)"$', '$1' -replace "^'(.*)'$", '$1' -replace "'", "''"
            $selectExpression += ".'$nodeWithDeactivatedQuotes'"
        }
        $finalNodePath = $this.UnlockQuotedNodes($selectExpression, $delimiter)
        return Invoke-Expression $finalNodePath
    }

    # "Locks" any nodes that are quoted by replacing the delimiter with an impossible delimiter.
    # This makes it safe to split on the delimiter without splitting literal delimiter characters, i.e., prevent splitting on delimiters inside quotes.
    # This is the logic that allows the function to support nodepaths containing, e.g., literal delimiters like node1.'node2.prop'.node3 without having
    # to write node1/node2.prop/node3 (i.e., avoiding '.' as a delimiter when it's present as a literal character in quotes, a syntax normal PS supports)
    [string] LockQuotedNodes([string]$nodes, [string]$noRegexDelimiter) {
        return $nodes -replace
            "('[^'.]+)$noRegexDelimiter([^'.]+')", ('$1' + ([string][char]0x2561 * 3) + '$2') -replace
            "('[^"".]+)$noRegexDelimiter([^"".]+')", ('$1' + ([string][char]0x2561 * 3) + '$2')
    }
    # Once splitting on the delimiter has been performed, restore the original nodepath string by replacing the impossible delimiter with the actual delimiter.
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
            $PSObjectSelector.SetNestedObjectResults($delimiter, $searchSegments)
            
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