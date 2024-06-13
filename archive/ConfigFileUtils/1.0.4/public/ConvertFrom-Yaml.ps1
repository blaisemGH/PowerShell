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
        if ( !$fileLines ) {
            $err = [Management.Automation.ErrorRecord]::new("No input YamlCode!", $null, 'InvalidData', $null)
            $PSCmdlet.ThrowTerminatingError($err)
        }
        return [YamlConverter]::new($fileLines, $asHashTable).Import_YamlCode()
    }
}
