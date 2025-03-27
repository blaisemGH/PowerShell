Function Import-StructuredDataFile {
    param(
        [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [Alias('PSPath','LP')]
        [string[]]$Path,
        [Parameter(Position=0)]
        [Alias('type')]
        [DataTypes]$DataType
    )
    begin {
        $configType = if ( $DataType ) {
            [NewStructuredDataType]::GetDataType($DataType)
        }
    }
    process {
        Foreach ( $file in $Path ) {
            $validPath = Convert-Path -LiteralPath $file
            if ( $configType ) {
                $configType.Import($validPath)
            }
            else {
                [NewStructuredDataType]::GetDataTypeByFileExtension($validPath).Import()   
            }
        }
    }
}