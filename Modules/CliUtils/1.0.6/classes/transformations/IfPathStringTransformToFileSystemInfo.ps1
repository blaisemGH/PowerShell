using namespace System.Management.Automation

class IfPathStringTransformToFileSystemInfo : ArgumentTransformationAttribute {
    [object] Transform([EngineIntrinsics]$engineIntrinsics, [object] $inputData) {
        if ( !$inputData ) {
            return $PWD.Path
        }

        if ($inputData -match '^[.]|[*]$') {
            try { $paths = Convert-Path -Path $inputData -ErrorAction Stop } catch {return [string]$inputData}
            return $(
                foreach ( $item in $paths ) {
                    if ( Test-Path -LiteralPath $item ) {
                        Get-Item -LiteralPath $item -Force
                    }
                }
            )
            
        }

        if ( !(Test-Path $inputData) ) {
            return [string]$inputData
        }

        return $inputData
    }
}