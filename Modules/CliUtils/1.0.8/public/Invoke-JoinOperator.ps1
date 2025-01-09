function Invoke-JoinOperator {
    param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [object]$InputObject,

        [Parameter(Mandatory, Position = 1)]
        [string]$joinString
    )
    end {
        $Input -join $joinString
    }
}