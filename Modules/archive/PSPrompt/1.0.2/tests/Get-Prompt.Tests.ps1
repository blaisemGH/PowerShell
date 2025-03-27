BeforeAll {
    $originalConfigDict = @{}
    [PSPromptConfig] | Get-Member -MemberType Properties -Static | foreach {
        $prop = $_.Name
        $value = [PSPromptConfig]::$prop
        $originalConfigDict.$prop = $value
    }
    function prompt{ [PSPrompt]::GetPrompt() }
    $currentPath = $PWD
}
BeforeEach {
    [PSPromptConfig] | Get-Member -MemberType Properties -Static | foreach {
        $prop = $_.Name
        [PSPromptConfig]::$prop = $null
    }
}
Describe 'Get-Prompt' {
    It 'uses the default config' {
        Get-Module PSPrompt | select -exp ModuleBase | Set-Location
        $defaultConfigValue = "`e[0m" + $PWD.Path + " `e[0m>"
        $prompt = prompt
        $prompt | Should -Be $defaultConfigValue
    }

    It 'uses a minimal config' {
        $getPSVersion = { 'PS' + $PSVersionTable.PSVersion.ToString() + ' ' }
        $promptTemplateGetPSVersion = @{
            'Alignment' = 'Left'
            'ItemSeparator' = ''
            'AnsiEffects' = 'italicize'
            'BackgroundColor' = '20;90;169'
            'ContentFunction' = $getPSVersion
            'DoNotRecalculateContentValue' = $true
        }
        Add-PSPromptTemplateItem @promptTemplateGetPSVersion
        $prompt = prompt
        $prompt | Should -Be "`e[0m`e[1;48;2;20;90;169m`e[3mPS$($PSVersionTable.PSVersion.ToString()) `e[0m>"
    }

    It 'tests left and right alignment' {
        $getPSVersion = { 'PS' + $PSVersionTable.PSVersion.ToString() + ' ' }
        $leftPromptTemplateGetPSVersion = @{
            'Alignment' = 'Left'
            'ItemSeparator' = ''
            'AnsiEffects' = 'italicize'
            'BackgroundColor' = '20;90;169'
            'ContentFunction' = $getPSVersion
            'DoNotRecalculateContentValue' = $true
        }
        Add-PSPromptTemplateItem @leftPromptTemplateGetPSVersion
        $rightPromptTemplateGetPSVersion = @{
            'Alignment' = 'Right'
            'ItemSeparator' = ''
            'AnsiEffects' = 'italicize'
            'BackgroundColor' = '20;90;169'
            'ContentFunction' = $getPSVersion
        }
        Add-PSPromptTemplateItem @rightPromptTemplateGetPSVersion

        $prompt = prompt
        $value = "`e[0m`e[1;48;2;20;90;169m`e[3mPS$($PSVersionTable.PSVersion.ToString()) `e[0m>"
        $lengthMiddleWhiteSpace = [Console]::WindowWidth - 1 - ( $value -replace "`e[^m]+m").length * 2
        
        $prompt | Should -Be "┌$value" + (' ' * $lengthMiddleWhiteSpace) + $value
        ($prompt -replace "`e[^m]+m").Length -split "\r?\n" | Select-Object -First 1 | Should -Be [Console]::WindowWidth
    }

    It 'tests first line overflow (left + right greater than screen width)' {
        $windowWidth = [Console]::WindowWidth
        $getPSVersion = { 'PS' + $PSVersionTable.PSVersion.ToString() + ' ' }
        $getPSVersionLong = { ('a' * $windowWidth) + 'PS' + $PSVersionTable.PSVersion.ToString() + ' ' }
        $leftPromptTemplateGetPSVersion = @{
            'Alignment' = 'Left'
            'ItemSeparator' = ''
            'AnsiEffects' = 'italicize'
            'BackgroundColor' = '20;90;169'
            'ContentFunction' = $getPSVersion
        }
        Add-PSPromptTemplateItem @leftPromptTemplateGetPSVersion
        $rightPromptTemplateGetPSVersion = @{
            'Alignment' = 'Right'
            'ItemSeparator' = ''
            'AnsiEffects' = 'italicize'
            'BackgroundColor' = '20;90;169'
            'ContentFunction' = $getPSVersionLong
        }
        Add-PSPromptTemplateItem @rightPromptTemplateGetPSVersion

        $prompt = prompt
        $value = "`e[0m`e[1;48;2;20;90;169m`e[3mPS$($PSVersionTable.PSVersion.ToString()) `e[0m>"
        $leftLength = $windowWidth - 1 - ( $value -replace "`e[^m]+m").length
        
        $prompt | Should -Be "┌$value" + (' ' * $leftLength) + '│ ' + '' + ('a' * $windowWidth) + "PS$($PSVersionTable.PSVersion.ToString()) `e[0m>"
    }

    It 'tests multiple items in a group' {}

    It 'tests multiple groups in a line' {}

    It 'tests a 2 line config' {}

    It 'tests a 2 line config with connectors and starts on the 2nd line' {} # Use Set-PSPromptConfig btw

    It 'tests a 5 line config with connectors and beckon change' {}
}
AfterAll {
    [PSPromptConfig] | Get-Member -MemberType Properties -Static | foreach {
        [PSPromptConfig]::$prop = $originalConfigDict.$prop
    }
    Set-Location $currentPath
}