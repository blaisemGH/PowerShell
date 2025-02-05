class MemoryUnitDTO {
    [double]$Memory
    [MemoryUnits]$Units
}
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
    [MemoryUnits]$InputUnits
    [MemoryUnits]$OutputUnits

    MemoryUnitConverter([string]$memory){
        if ( $memory -match 'azA-Z' ) {
            $this.Memory, $this.InputUnits = $memory -split '(?<=\d)(?=[a-zA-Z])'
            $this.OutputUnits = $this.InputUnits   
        } else {
            $this.Memory = $memory
            $this.InputUnits = 'B'
            $this.OutputUnits = 'B'
        }
    }
    MemoryUnitConverter([double]$memory, [MemoryUnits]$outputUnits){
        $this.Memory = $memory
        $this.InputUnits = 'B'
        $this.OutputUnits = $outputUnits
    }
    MemoryUnitConverter([string]$memory, [MemoryUnits]$outputUnits){
        $this.Memory, $this.InputUnits = $memory -split '(?<=\d)(?=[a-zA-Z])'
        
        if ( ! $this.InputUnits ) {
            $this.InputUnits = 'B'
        }
        
        $this.OutputUnits = $outputUnits
    }
    MemoryUnitConverter([string]$memory, [MemoryUnits]$inputUnits, [MemoryUnits]$outputUnits){
        $this.Memory = $memory
        $this.InputUnits = $inputUnits
        $this.OutputUnits = $outputUnits
    }

    [MemoryUnitDTO] ConvertMemory () {
        return $this.ConvertMemory($this.Memory, $this.OutputUnits)
    }

    [MemoryUnitDTO] ConvertMemory ([string]$inputMemory) {
        return $this.ConvertMemory($inputMemory, $this.OutputUnits)
    }
    
    [MemoryUnitDTO] ConvertMemory ([string]$inputMemory, [MemoryUnits]$outputUnits) {
        # If someone tries to convert a new memory string, reparse the input units just in case
        $testMemory = $inputMemory -split '(?<=\d)(?=[a-zA-Z])'
        $inputUnits = if ($testMemory.Count -gt 1) {
            $testMemory[1]
        } else {
            $this.InputUnits
        }

        # If the input units are the same as the output units, then no conversion is necessary.
        # Also need to check for the default of adding a b, e.g., g = gb by default.
        if ($inputUnits -eq $outputUnits -or 
            ($inputUnits + 'b') -eq $outputUnits -or 
            $inputUnits -eq ($outputUnits + 'b')
        ) {
            return $inputMemory
        }
    
        $memoryInBytes = $this.DownscaleMemoryToBytes($inputMemory, $inputUnits)
        $memoryInOutputUnits = $this.UpscaleMemoryFromBytes($memoryInBytes, $outputUnits)

        return [MemoryUnitDTO]@{
            Memory = $memoryInOutputUnits
            Units = $this.OutputUnits
        }
    }

    [double] ConvertFromBinary ([double]$memory, [MemoryUnits]$binaryUnit) {
        $multiplierFactor = $this.GetUnitMultiplier($binaryUnit)
        $conversionFactor = [Math]::Pow(1.024, $multiplierFactor)
        
        return $memory * $conversionFactor
    }

    [double] ConvertToBinary ([double]$memory, [MemoryUnits]$binaryUnit) {
        $multiplierFactor = $this.GetUnitMultiplier($binaryUnit)
        $conversionFactor = [Math]::Pow(1.024, $multiplierFactor)
        
        return $memory / $conversionFactor
    }

    [double] DownscaleMemoryToBytes([double]$memory, [MemoryUnits]$unit) {
        return $(
            switch -Regex ($unit.ToString()) {
                'i$' {
                    $decimalMemory = $this.ConvertFromBinary($memory, $_)
                    $baseUnit = $_ -replace 'i$', 'b'
                    $decimalMemory * "1$baseUnit"
                    break
                }
                '^[bB]$' {
                    $memory
                    break
                }
                '^[ac-zAC-Z]$' {
                    $memory * "1${_}b"
                }
                default {
                    $memory * "1$_"
                }
            }
        )
    }

    [double] UpscaleMemoryFromBytes([double]$memory, [MemoryUnits]$unit) {
        return $(
            switch -Regex ($unit.ToString()) {
                'i$' {
                    $binaryMemory = $this.ConvertToBinary($memory, $_)
                    $baseUnit = $_ -replace 'i$', 'b'
                    $binaryMemory / "1$baseUnit"
                    break
                }
                '^[bB]$' {
                    $memory
                    break
                }
                '^[ac-zAC-Z]$' {
                    $memory / "1${_}b"
                }
                default {
                    $memory / "1$_"
                }
            }
        )
    }

    [MemoryUnits] GetUnitMultiplier([MemoryUnits]$unit) {
        $baseUnit = switch ($unit.ToString()) {
            {$_.Length -in 1,2} { $_.Substring(0,1) }
            {$_.Length -gt 2} { Throw "Unit $unit has too many characters. Must be 1 or 2 characters."}
            default {$_}
        }
        
        if ( $baseUnit -notin $this.ConversionTable.Keys ) {
            Throw "Base unit $baseUnit from $unit not recognizable! Must be one of $($this.conversionTable.Keys)"
        }
        
        return $this.ConversionTable.$baseUnit
    }
}