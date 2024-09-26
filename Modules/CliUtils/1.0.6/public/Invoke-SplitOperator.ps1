function Invoke-SplitOperator {
    param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [object]$InputObject,

        [Parameter(Mandatory, Position = 1)]
        [string]$patternToSplitOn,

        [Parameter(Position = 2)]
        [int]$howManyDelimitersToSplit
    )
    process {
        foreach ($object in $InputObject) {
            $object -split $patternToSplitOn, $howManyDelimitersToSplit
        }
    }
}