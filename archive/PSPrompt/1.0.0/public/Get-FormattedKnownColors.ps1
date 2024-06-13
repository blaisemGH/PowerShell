using namespace System.Drawing
function Get-FormattedKnownColors {
    [KnownColor].GetEnumNames() | % {
        $color = [Color]$_
        $red = $color.R
        $green = $color.G
        $blue = $color.B
        $exampleForeground = "`e[1;38;2;$red;$green;${blue}mSample Text"
        $exampleBackground = "`e[1;48;2;$red;$green;${blue}mSample Text"
        [PSCustomObject]@{
            Color = $color.Name
            R = $red
            G = $green
            B = $blue
            Background = $exampleBackground
            Foreground = '{0,-20}' -f $exampleForeground
        }
    } | Group-Object R, B, G | # Group to remove duplicates.
        ForEach-Object {
            $_.group[0] # Only take first entry in duplicates
        } |
        Sort-Object R, G, B
}