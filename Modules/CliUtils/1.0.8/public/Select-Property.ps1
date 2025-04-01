function Select-Property {
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
        [string]$NodeSeparator = '.',
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
            
            $PSObjectSelector.GetFinalResults($ExpandProperties)
        }
    }
}
