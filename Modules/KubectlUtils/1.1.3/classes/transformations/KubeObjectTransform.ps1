class KubeObjectTransform : ArgumentTransformationAttribute {
    [object] Transform([EngineIntrinsics]$engineIntrinsics, [object] $inputData) {
        if ( $inputData -match '[^$*]' ) {
            return $inputData
        }
        return "*$inputData*"
    }
}