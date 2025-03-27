using namespace System.Collections.Generic
using namespace System.Management.Automation

Function ConvertFrom-Yaml {
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowEmptyString()]
        [string[]]$yamlCode
    )

    begin {
        $yamlCollection = [List[string]]::new()
    }
    process {
        foreach ($line in $yamlCode) {
            $yamlCollection.Add($line)
        }
    }
    end {
        if ( !$yamlCollection ) {
            $err = [ErrorRecord]::new("No input YamlCode!", $null, 'InvalidData', $null)
            $PSCmdlet.ThrowTerminatingError($err)
        }
        return [YamlData]::new().ConvertFrom($yamlCollection)
    }
}
