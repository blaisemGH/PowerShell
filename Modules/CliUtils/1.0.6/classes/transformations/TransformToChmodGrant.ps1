using namespace System.Management.Automation

class TransformToChmodGrant : ArgumentTransformationAttribute {
    [object] Transform([EngineIntrinsics]$engineIntrinsics, [object] $inputData) {
        $target = if ( $inputData -match '^[ugo]' ) { $inputData[0] } else { 'o' }
        $permissions = $inputData.Trim('ugo') -replace '[,+ ]' -join ''
        return "$target+$permissions"
    }
}