Function Measure-KubeContainers {
    Param(
        [Parameter(ValueFromPipelineByPropertyName)]
        [object]$containers
    )
    process {
        return $containers | Select-Object @{
            'l' = 'Container'
            'e' = { $_.name }
        }, @{
            'l' = 'cpu'
            'e' = {
                $cpu = $_.usage | select -exp cpu
                [int64]$usage = $cpu -replace '[a-z]$'
                $unit = $cpu[-1]
            
                [Math]::Round( $(
                    switch ($unit) {
                        'n' { $usage / 1000 / 1000 /1000}
                        'u' { $usage / 1000 / 1000 }
                        'm' { $usage / 1000 }
                        default {$usage}
                    }
                ), 3)
            }
        }, @{
            'l' = 'memoryGB'
            'e' = {
                $memory = $_.usage | select -exp memory | Convert-MemoryUnits -ToUnits Gb | Select-Object -ExpandProperty Memory
                [int64]$usage = $memory -replace '[a-z]{2}$'
                $unit = $memory[-2..-1] -join '' -replace '[0-9]'
            
                [Math]::Round($memory, 3)
            }
        }
    }
}
