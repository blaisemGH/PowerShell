New-ConfigUtility {
    param(
        [Parameter(Mandatory)]
        [Alias('type')]
        [string]$Extension
    )
    return switch -Regex ($Extension) {
        ^.ya?ml$ {[YamlConfigFile]::new()}
        ^.jso?n$ {}
        ^.csv$ {}
        ^.ini$ {}
        ^.xml$ {}
        ^.properties$ {}
        ^.txt$ {}
        ^.to?ml$ {}
        ^.psd1$ {}
        ^.ps1$ {}
    }
}