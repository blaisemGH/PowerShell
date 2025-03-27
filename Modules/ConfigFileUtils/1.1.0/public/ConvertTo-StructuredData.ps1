Function ConvertTo-StructuredData {
    param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [object[]]$InputObject,
        [Parameter(Mandatory, Position=0)]
        [Alias('type')]
        [DataTypes]$DataType
    )
    begin {
        $configType = [NewStructuredDataType]::GetDataType($DataType)
    }
    process {
        Foreach ( $item in $InputObject ) {
            $configType.ConvertTo($item)
        }
    }
}