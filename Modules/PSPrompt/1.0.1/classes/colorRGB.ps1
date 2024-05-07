using namespace System.Drawing
class colorRGB {
    [int]$R
    [int]$G
    [int]$B
    
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
            }
            else {
                $colors -split ';'
            }
        }
        $this.R = $c[0]
        $this.G = $c[1]
        $this.B = $c[2]
    }
    
    static [object] TryParseString ([string]$colors) {
        if ( $colors -match ';' ) {
            $c = $colors -split ';'
            $red    = $c[0]
            $green  = $c[1]
            $blue   = $c[2]

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

    [string] ToString() {
        return "$($this.red);$($this.green);$($this.blue)"
    }
}