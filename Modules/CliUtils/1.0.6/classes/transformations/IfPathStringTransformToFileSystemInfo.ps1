using namespace System.Management.Automation

class IfPathStringTransformToFileSystemInfo : ArgumentTransformationAttribute {
    [object] Transform([EngineIntrinsics]$engineIntrinsics, [object] $inputData) {
        $pathToTest = & {
            if ( !$inputData ) {
                $PWD.Path
            }
            elseif ($inputData -match '^[.]|[*]$') {
                Convert-Path -LiteralPath $inputData -ErrorAction Stop
            }
            else {
                $inputData
            }
        }
        if ( Test-Path -LiteralPath $inputData ) {
            return Get-Item $inputData -Force
        }
        return $inputData
    }
}