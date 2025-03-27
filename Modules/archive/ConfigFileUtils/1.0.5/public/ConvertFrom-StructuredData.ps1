using namespace System.Collections.Generic

Function ConvertFrom-StructuredData {
    param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [string[]]$InputObject,
        [Parameter(Mandatory,Position=0)]
        [Alias('type')]
        [DataTypes]$DataType
    )
    begin {
        $configType = [NewStructuredDataType]::GetDataType($DataType)
        $dataCollection = [List[string]]::new()
    }
    process {
        Foreach ( $line in $InputObject ) {
            $dataCollection.AddRange($line)
        }
    }
    end {
        $configType.ConvertFrom($dataCollection)
    }
}