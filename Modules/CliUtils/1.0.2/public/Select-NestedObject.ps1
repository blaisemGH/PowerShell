function Select-NestedObject {
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object]$InputObject,

        [Parameter(Position=0, ValueFromRemainingArguments)]
        [string[]]$PropertyNodes
    )
    begin {
        
        $delimiter = ($PropertyNodes -join ' ' -replace '[\w$]' -replace '^\s+$', ' ')[0]
write-host $delimiter
        $selectExpression = '($InputObject)'
        if ( $delimiter ) {
            write-host 'check'
            ForEach ($node in ($PropertyNodes -split ('\s*' + [Regex]::Escape($delimiter) + '\s*') | Where {$_})) {
                $selectExpression += ".$node"
            }
        }
        else {
            write-host $PropertyNodes
            $selectExpression += ".$PropertyNodes"
        }
    }
    process {
        write-host $inputobject
        write-host $PropertyNodes
        write-host 'hello'
        Invoke-Expression $selectExpression
    }
}