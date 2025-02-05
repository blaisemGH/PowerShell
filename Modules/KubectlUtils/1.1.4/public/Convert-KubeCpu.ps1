function Convert-KubeCpu {
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$Cpu
    )

    process {
        foreach ($item in $Cpu) {
            switch -regex ($item) {
                'm$' {
                    [double]($_.Trim('m')) / 1000
                }
                'u$' {
                    [double]($_.Trim('u')) / 1000 / 1000
                }
                'n$' {
                    [double]($_.Trim('n')) / 1000 / 1000 / 1000
                }
                default { [double]$_ }
            }
        }
    }
}