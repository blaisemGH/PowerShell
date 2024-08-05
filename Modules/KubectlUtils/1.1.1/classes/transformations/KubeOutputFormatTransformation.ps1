class KubeOutputFormatTransform : ArgumentTransformationAttribute {
    [object] Transform([EngineIntrinsics]$engineIntrinsics, [object] $inputData) {
        $outputArg = $inputData -split '=', 2
        $transform = switch ($outputArg[0]) {
            cc { custom-columns }
            j { json; break }
            jp { jsonpath}
            gt { go-template }
            DEFAULT { $_ }
        }
        $type = $transform -as [KubeOutputFormats]
        if ( $outputArg[1] ) {
            $value = if ( $type -eq jsonpath ) { $outputArg[1] -replace "^'|'$" -replace '^\{|\}$' } else { $outputArg[1] }
            return $type + '=' + $value
        }
        return $type
    }
}