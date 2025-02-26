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
        # If someone tries to convert a new memory string, reparse the input units just in case they've been changed.
        $testMemory = $inputMemory -split '(?<=\d)(?=[a-zA-Z])'
        $inputUnitsToUse = if ($testMemory.Count -gt 1) {
            $testMemory[1]
        } else {
            $this.InputUnits
        }

        # If the input units are the same as the output units, then no conversion is necessary.
        # Also need to check for the default of adding a b, e.g., g = gb by default in this class.
        if ($inputUnitsToUse -eq $outputUnits -or 
            ($inputUnitsToUse + 'b') -eq $outputUnits -or 
            $inputUnitsToUse -eq ($outputUnits + 'b')
        ) {
            return $inputMemory
        }
    
        $memoryInBytes = $this.DownscaleMemoryToBytes($inputMemory, $inputUnitsToUse)
        $memoryInOutputUnits = $this.UpscaleMemoryFromBytes($memoryInBytes, $outputUnits)

        return [MemoryUnitDTO]@{
            Memory = $memoryInOutputUnits
            Units = $this.OutputUnits
        }
    }

    [double] DownscaleMemoryToBytes([double]$memory, [MemoryUnits]$unit) {
        return $(
            switch -Regex ($unit.ToString()) {
                '^[a-zA-Z]i$' {
                    $baseUnit = $_ -replace 'i$', 'b'
                    $memory * "1$baseUnit"
                    break
                }
                '^[bB]$' {
                    $memory
                    break
                }
                '^[ac-zAC-Z]$' {
                    $binaryMemory = $this.ConvertFromDecimalToBinary($memory, $_)
                    $binaryMemory * "1${_}b"
                    break
                }
                default {
                    $binaryMemory = $this.ConvertFromDecimalToBinary($memory, $_)
                    $binaryMemory * "1$_"
                }
            }
        )
    }

    [double] UpscaleMemoryFromBytes([double]$memory, [MemoryUnits]$unit) {
        return $(
            switch -Regex ($unit.ToString()) {
                '^[a-zA-Z]i$' {
                    $baseUnit = $_ -replace 'i$', 'b'
                    $memory / "1$baseUnit"
                    break
                }
                '^[bB]$' {
                    $memory
                    break
                }
                '^[ac-zAC-Z]$' {
                    $binaryMemory = $memory / "1${_}b"
                    $this.ConvertFromBinaryToDecimal($binaryMemory, $_)
                    break
                }
                default {
                    $binaryMemory = $memory / "1$_"
                    $this.ConvertFromBinaryToDecimal($binaryMemory, $_)
                }
            }
        )
    }

    [double] ConvertFromDecimalToBinary ([double]$memory, [MemoryUnits]$unit) {
        $conversionFactor = $this.GetMemoryFormatConversionFactor($unit)
        return $memory / $conversionFactor
    }

    [double] ConvertFromBinaryToDecimal ([double]$memory, [MemoryUnits]$unit) {
        $conversionFactor = $this.GetMemoryFormatConversionFactor($unit)
        return $memory * $conversionFactor
    }

    [double] GetMemoryFormatConversionFactor([MemoryUnits]$unit) {
        $baseUnit = switch ($unit.ToString()) {
            {$_.Length -in 1,2} { $_.Substring(0,1) }
            {$_.Length -gt 2} { Throw "Unit $unit has too many characters. Must be 1 or 2 characters."}
            default {$_}
        }
        
        if ( $baseUnit -notin $this.ConversionTable.Keys ) {
            Throw "Base unit $baseUnit from $unit not recognizable! Must be one of $($this.conversionTable.Keys)"
        }
        
        return [Math]::Pow(1.024, $this.ConversionTable.$baseUnit)
    }
}