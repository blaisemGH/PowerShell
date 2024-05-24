class ConvertToFullPathTransform : System.Management.Automation.ArgumentTransformationAttribute {
    [object] Transform([EngineIntrinsics]$engineIntrinsics, [object] $inputData) {
        try {
            return Convert-Path $inputData -ErrorAction Stop
        } catch [ItemNotFoundException] {
            return $_.TargetObject
        }
    }
}