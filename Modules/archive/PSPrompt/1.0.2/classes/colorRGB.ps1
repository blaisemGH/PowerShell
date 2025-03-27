using namespace System.Drawing
class colorRGB {
    [int]$R
    [int]$G
    [int]$B
    static [hashtable] $mapIntToHex = @{
        0=0; 1=1; 2=2; 3=3; 4=4; 5=5; 6=6; 7=7; 8=8; 9=9
        10='A'; 11='B'; 12='C'; 13='D'; 14='E'; 15='F'
    }
    
    colorRGB([int]$red, [int]$green, [int]$blue) {
        $this.R = $red
        $this.G = $green
        $this.B = $blue
    }
    colorRGB([string]$colors) {
        $c = & {
            if ( $colors -match '^#' ) {
                [Convert]::ToInt32($colors.TrimStart('#').Substring(0,2), 16),
                [Convert]::ToInt32($colors.TrimStart('#').Substring(2,2), 16),
                [Convert]::ToInt32($colors.TrimStart('#').Substring(4,2), 16)
            } elseif ( $colors -as [Color] ) {
                $newColor = $colors -as [Color]
                $newColor.R, $newColor.G, $newColor.B
            } else {
                $colors -split ';'
            }
        }
        $this.R = $c[0]
        $this.G = $c[1]
        $this.B = $c[2]
    }
    
    static [object] TryParseString ([string]$colors) {
        if ( $colors -match ';' ) {
            $c = $colors -replace '^.*;([0-9]+(?:;[0-9]{1,3}){2})m?$','$1' -split ';'
            $red    = $c[0]
            $green  = $c[1]
            $blue   = $c[2]
            if ( ! ($red -as [int] -and $green -as [int] -and $blue -as [int])) {
                Write-Host "Failed to parse string to int for input string: $($colors -replace "`e\["). Parsed as: $c"
            }
            try {
                return [ColorRGB]::new($red, $green, $blue)
            }
            catch { return $null }
        }
        elseif ( $colors -match '^#' ) {
            $red    = [Convert]::ToInt32($colors.TrimStart('#').Substring(0,2), 16)
            $green  = [Convert]::ToInt32($colors.TrimStart('#').Substring(2,2), 16)
            $blue   = [Convert]::ToInt32($colors.TrimStart('#').Substring(4,2), 16)

            try {
                return [ColorRGB]::new($red, $green, $blue)
            } catch { return $null }
        }
        elseif ( $colors -as [KnownColor] ) {
            $c = [Color]$colors
            return [ColorRGB]::new($c.R, $c.G, $c.B)
        }
        else {
            return $null
        }
    }
    
    [string] ConvertColorRGBToAnsi ([bool]$isBackground) {
        $ground = 38 + 10 * $isBackground
        $red    = $this.R
        $green  = $this.G
        $blue   = $this.B
        
        return "`e[1;$ground;2;$red;$green;${blue}m"
    }

    static [string] ConvertColorIntToHexCode ([int]$int) {
        $leftHex = [Math]::Floor($int / 16)
        $rightHex = $int % 16
        
        return '#{0}{1}' -f [ColorRGB]::mapIntToHex.$leftHex, [ColorRGB]::mapIntToHex.$rightHex
    }
    static [string] ConvertColorIntToHexCode ([int]$red, [int]$green, [int]$blue) {
        $hexString = '#'
        $red, $green, $blue | Foreach {
            [int]$leftHex = [Math]::Floor($_ / 16)
            [int]$rightHex = $_ % 16
            $hexString += '{0}{1}' -f [ColorRGB]::mapIntToHex.$leftHex, [ColorRGB]::mapIntToHex.$rightHex
        }
        return $hexString
    }

    [string] ToString() {
        return "$($this.red);$($this.green);$($this.blue)"
    }
}