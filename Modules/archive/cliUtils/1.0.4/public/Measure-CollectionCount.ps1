function Measure-CollectionCount {
    param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [object]$InputObject
    )
    end {
        $Input.Count
    }
}