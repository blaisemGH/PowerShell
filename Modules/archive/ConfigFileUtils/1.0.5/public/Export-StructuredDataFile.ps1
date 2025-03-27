using namespace System.Collections.Generic
using namespace System.Management.Automation

Function Export-StructuredDataFile {
    param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [string[]]$InputObject,
        [Parameter(Mandatory, Position=0)]
        [string]$Path,
        [Parameter(Position=1)]
        [Alias('type')]
        [DataTypes]$DataType,
        [switch]$Append
    )
    begin {
        $configType = if ( $DataType ) {
            [NewStructuredDataType]::GetDataType($DataType)
        } 
        $inputCollection = [List[object]]::new()
        $fullPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    }
    process {
        Foreach ( $line in $InputObject ) {
            $inputCollection.AddRange($line)
        }
    }
    end {
        if ( $configType ) {
            $configType.Export($inputCollection, $fullPath, $Append)
        }
        elseif (!$configType -and ( Test-Path -LiteralPath $fullPath ) ) {
            [NewStructuredDataType]::GetDataTypeByFileExtension($fullPath).Export($inputCollection, $Append)
        }
        else {
            $err = [ErrorRecord]::new("No DataType parameter $DataType specified, and path $fullPath is not an existing file!", $null, 'InvalidArgument', $null)
            $PSCmdlet.ThrowTerminatingError($err)
        }
    }
}