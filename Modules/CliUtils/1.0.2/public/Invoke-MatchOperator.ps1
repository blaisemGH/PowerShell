function Invoke-MatchOperator {
    param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [object]$InputObject,

        [Parameter(Mandatory, Position = 1)]
        [string]$patternToMatch
    )
    end {
        $Input -match $patternToMatch
    }
}