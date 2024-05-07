function Get-ObjectType {
    param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [object]$InputObject
    )
    end {
        $Input.GetType()
    }
}