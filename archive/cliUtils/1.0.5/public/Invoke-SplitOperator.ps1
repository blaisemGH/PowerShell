function Invoke-SplitOperator {
    param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [object]$InputObject,

        [Parameter(Mandatory, Position = 1)]
        [string]$patternToSplitOn,
        
        [string]$howManyDelimitersToSplit
    )
    process {
        foreach ($object in $InputObject) {
            $object -split $patternToSplitOn, $howManyDelimitersToSplit
        }
    }
}