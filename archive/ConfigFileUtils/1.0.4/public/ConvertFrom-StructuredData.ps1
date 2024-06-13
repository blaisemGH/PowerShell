ConvertFrom-StructuredData {
    param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [string[]]$InputObject,
        [Parameter(Mandatory,Position=0)]
        [Alias('type')]
        [FileExtensions]$DataType
    )
    begin {
        $configType = New-ConfigBuilder $DataType
    }
    process {
        $configType.ConvertFrom($InputObject)
    }
}