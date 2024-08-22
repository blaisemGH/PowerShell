class FilePathStringToFileSystemInfoAttribute : Management.Automation.ArgumentTransformationAttribute {

    [object] Transform([Management.Automation.EngineIntrinsics] $engineIntrinsics, [object] $input) {
        if ( $input -isnot [System.IO.FileSystemInfo]) {
            if ( Test-Path $input ) {
                return Get-Item $input
            }
            else {
                return $input
            }
        }
    }
}