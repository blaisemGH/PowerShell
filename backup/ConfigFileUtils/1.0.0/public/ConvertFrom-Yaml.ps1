using namespace System.Collections.Generic

Function ConvertFrom-Yaml {
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowEmptyString()]
        [string[]]$yamlCode,
        [switch]$asHashTable
    )
    begin {
        $fileLines = [List[string]]@()
    }
    process {
        $fileLines.AddRange($yamlCode)
    }
    end {
        $out = ([YamlUtils]::new($fileLines, $asHashTable).Parse() -join [Environment]::NewLine)
        write-debug $out
        Invoke-Expression $out
    }
}
