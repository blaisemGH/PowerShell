using namespace System.Collections.Generic

Function ConvertTo-Yaml {
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object[]]$InputObject
    )

    begin {
        $yamlBuilder = [YamlData]::new()
    }
    process {
        foreach ($item in $InputObject) {
            $yamlBuilder.ConvertTo($item)
        }
    }
}
