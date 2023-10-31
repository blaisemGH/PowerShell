class ItemSize {
	[string]$Item
	[string]$Size
	hidden [int64]$Length
	hidden [string]$FullName
	hidden [string]$name

	ItemSize([string]$fullPath, [int64]$rawLength) {
		$this.Construct_Paths($fullPath)
		$this.Construct_Length($rawLength)
	}
	ItemSize([string]$fullPath, [int64]$rawLength, [string]$unit) {
		$this.Construct_Paths( $fullPath )
		$this.Construct_Length( $rawLength, $unit)
	}

	[void]Construct_Paths ( [string]$fullPath ) {
		$currentDir = $PWD.Path
		$this.Item = (Get-Item $fullPath).FullName -Replace [Regex]::Escape($currentDir),'.'
		$this.FullName = $fullPath
		$this.Name = Split-Path $fullPath -Leaf
	}

	[void]Construct_Length ( [int64]$rawLength ) {
		$this.Size = [ItemSize]::Get_Size($rawLength)
		$this.Length = $rawLength
	}
	[void]Construct_Length ( [int64]$rawLength, [string]$unit ) {
		If ( ($divideByUnit = $unit) -eq 'B' ) {
			$divideByUnit = $null
		}
		$this.Size = '{0, -7} {1}' -f ($rawLength / "1$divideByUnit"), $unit
		$this.Length = $rawLength
	}

	static [string]Get_Size ([int64]$rawLength) {
		If ( !$rawLength ) {
			Return '{0, -7}  b' -f '0'
		}
		Else {
			$convertUnit = [math]::Floor([math]::log($rawLength,  1024))
			$logSize     = [Math]::Round($rawLength / [math]::Pow(1024,$convertUnit),3)
			$calcUnit = Switch ( $convertUnit ) {
				0 { " b" }
				1 { "Kb" }
				2 { "Mb" }
				3 { "Gb" }
				4 { "Tb" }
				5 { "Pb" }
				6 { "Eb" }
				7 { "Zb" }
				8 { "Yb" }
				Default { '' }
			}
			Return ('{0, -7} {1}' -f $logSize.ToString(), $calcUnit)
		}
	}
}