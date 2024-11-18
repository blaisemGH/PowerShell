using namespace System.Management.Automation

class IfPathStringTransformToFileSystemInfo : ArgumentTransformationAttribute {
    [object] Transform([EngineIntrinsics]$engineIntrinsics, [object] $inputData) {
        if ( !$inputData ) {
            return $PWD.Path
        }

        # Check if this a property by name input with a path
        $pathProperty = $null
        if ($inputData -is [PSCustomObject]) {
            $pathProperty = ($inputData.psobject.properties.name -match '^(LP|LiteralPath|PSPath|Path|FullName)$')[0]
            if ( $pathProperty ) {
                return Get-Item -LiteralPath ($inputData.$pathProperty) -Force
            }
        }

        # handle inputs beginning with a . (relative path or multiple paths) or ending with an * (also a potential multi path)
        if ($inputData -match '^[.]|[*]$') {
            try { $paths = Convert-Path -Path $inputData -ErrorAction Stop } catch {return [string]$inputData}
            return $(
                foreach ( $item in $paths ) {
                    #if ( Test-Path -LiteralPath $item ) {
                        Get-Item -LiteralPath $item -Force
                    #}
                }
            )
            
        }

        # Return as string if not a valid path
        if ( !(Test-Path $inputData) ) {
            return [string]$inputData
        }

        # Assume a valid path based on previous if, check if already filesystem object
        if ( $inputData -is [IO.FilesystemInfo] ) {
            return $inputData
        }
        # Assume a valid path based on 2 ifs ago, return as filesystem object
        return Get-Item $inputData -Force
    }
}