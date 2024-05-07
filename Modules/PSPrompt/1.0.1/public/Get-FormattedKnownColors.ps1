using namespace System.Drawing
function Get-FormattedKnownColors {
    param(
        [string]$TextToSample = 'Sample Text'
    )
    [KnownColor].GetEnumNames() | % {
        $color = [Color]$_
        $red = $color.R
        $green = $color.G
        $blue = $color.B
        $exampleForeground = "`e[1;38;2;$red;$green;${blue}m$TextToSample"
        $exampleBackground = "`e[1;48;2;$red;$green;${blue}m$TextToSample"
        [PSCustomObject]@{
            Color = $color.Name
            R = $red
            G = $green
            B = $blue
            Background = $exampleBackground + '     '
            Foreground = $exampleForeground
        }
    } | Group-Object R, G, B | # Group to remove duplicates.
        ForEach-Object {
            $_.group[0] # Only take first entry in duplicates
        } |
        Sort-Object R, G, B
}