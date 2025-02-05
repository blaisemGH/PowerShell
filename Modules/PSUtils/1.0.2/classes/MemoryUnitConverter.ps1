class MemoryUnitConverter {
    [hashtable]$ConversionTable = @{
        B = 0
        K = 1
        M = 2
        G = 3
        T = 4
        P = 5
        E = 6
        Z = 7
        Y = 8
    }
    [double]$Memory
    [string]$InputUnits
    [string]$Units

    MemoryUnitConverter([double]$memory, [string]$outputUnits){
        $this.Memory = $memory
        $this.InputUnits = 'B'
        $this.Units = $outputUnits
    }
    MemoryUnitConverter([string]$memory, [string]$outputUnits){
        $this.Memory, $this.InputUnits = $memory -split '(?<=\d)(?=[a-zA-Z])'
        
        if ( ! $this.InputUnits ) {
            $this.InputUnits = 'B'
        }
        
        $this.Units = $outputUnits
    }
    MemoryUnitConverter([double]$memory, [string]$inputUnits, [string]$outputUnits){
        $this.Memory = $memory
        $this.InputUnits = $inputUnits
        $this.Units = $outputUnits
    }

    [string] ConvertMemory () {
        return $this.ConvertMemory($this.Memory, $this.Units)
    }

    [string] ConvertMemory ([string]$inputMemory) {
        return $this.ConvertMemory($inputMemory, $this.Units)
    }

    [PSCustomObject] ConvertMemory ([string]$inputMemory, [string]$outputUnit) {
    
        $memoryInBytes = $this.DownscaleMemoryToBytes($this.Memory, $this.InputUnits)
        $memoryInOutputUnits = $this.UpscaleMemoryFromBytes($memoryInBytes, $this.Units)

        $finalMemory = switch -Regex ($this.Units) {
            'i$' {
                $this.ConvertToBinary($memoryInOutputUnits, $_)
            }
            default {
                $memoryInOutputUnits
            }
        }

        return [PSCustomObject]@{
            Memory = $finalMemory
            Units = $this.Units
        }
    }

    [double] ConvertFromBinary ([double]$memory, [string]$binaryUnit) {
        $multiplierFactor = $this.GetUnitMultiplier($binaryUnit)
        $conversionFactor = [Math]::Pow(1.024, $multiplierFactor)
        
        return $memory / $conversionFactor
    }

    [double] ConvertToBinary ([double]$memory, [string]$binaryUnit) {
        $multiplierFactor = $this.GetUnitMultiplier($binaryUnit)
        $conversionFactor = [Math]::Pow(1.024, $multiplierFactor)
        
        return $memory * $conversionFactor
    }

    [double] DownscaleMemoryToBytes([double]$memory, [string]$unit) {
        return $(
            switch -Regex ($unit) {
                'i$' {
                    $decimalMemory = $this.ConvertFromBinary($memory, $_)
                    $decimalUnit = $_ -replace 'i$', 'b'
                    $decimalMemory / "1$decimalUnit"
                    break
                }
                '^[bB]$' {
                    $memory
                    break
                }
                default {
                    $memory / "1$_"
                }
            }
        )
    }

    [double] UpscaleMemoryFromBytes([double]$memory, [string]$unit) {
        $multiplierFactor = $this.GetUnitMultiplier($unit)
        return $memory * $multiplierFactor * 1000
    }

    [string] GetUnitMultiplier([string]$unit) {
        $baseUnit = switch ($unit) {
            {$_.Length -eq 2} { $unit.Substring(0,1) }
            {$_.Length -gt 2} { Throw "Unit $unit has too many characters. Must be 1 or 2 characters."}
            default {$_}
        }
        
        if ( $baseUnit -notin $this.ConversionTable.Keys ) {
            Throw "Base unit $baseUnit from $unit not recognizable! Must be one of $($this.conversionTable.Keys)"
        }
        
        return $this.ConversionTable.$baseUnit
    }
}