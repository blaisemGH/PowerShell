using namespace System.Collections.Generic
using namespace System.Management.Automation

Function Export-YamlFile {
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowEmptyString()]
        [string[]]$yamlCode,
        [Parameter(Mandatory)]
        [string]$Path,
        [switch]$Append
    )

    begin {
        $yamlCollection = [List[string]]::new()
        $fullPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    }
    process {
        foreach ($line in $yamlCode) {
            $yamlCollection.AddRange($line)
        }
    }
    end {
        if ( !$yamlCollection ) {
            $err = [ErrorRecord]::new("No input YamlCode!", $null, 'InvalidData', $null)
            $PSCmdlet.ThrowTerminatingError($err)
        }
        return [YamlData]::new($fullPath).Export($yamlCollection, $fullPath, $Append)
    }
}
