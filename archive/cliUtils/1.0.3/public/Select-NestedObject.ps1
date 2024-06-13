function Select-NestedObject {
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object]$InputObject,

        [Parameter(Position=0, ValueFromRemainingArguments)]
        [string[]]$PropertyNodes,

        [Alias('s','sep')]
        [string]$NodeSeparator
    )
    begin {
        $delimiter = if ($NodeSeparator ) {
            $NodeSeparator
        } else {
            ($PropertyNodes -join ' ' -replace '[\w$]' -replace '^\s+$', ' ')[0]
        }

        $selectExpression = '($InputObject)'
        if ( $delimiter ) {
            ForEach ($node in ($PropertyNodes -split ('\s*' + [Regex]::Escape($delimiter) + '\s*') | Where {$_})) {
                $selectExpression += ".'$node'"
            }
        }
        else {
            $selectExpression += ".$PropertyNodes"
        }
    }
    process {
        Invoke-Expression $selectExpression
    }
}