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
		$fileLines.Add($yamlCode)
	}
	end {
		Invoke-Expression ([YamlUtils]::new($fileLines, $asHashTable).parse() -join [Environment]::NewLine)
	}
}