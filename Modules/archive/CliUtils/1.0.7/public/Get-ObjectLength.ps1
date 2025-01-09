function Get-ObjectLength {
    param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [object]$InputObject
    )
    end {
        $Input.Length
    }
}