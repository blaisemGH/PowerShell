using namespace System.Collections.Generic
using namespace System.IO
#User-specific settings. Adapt as necessary.

    # Adds useful programs to your path variable, so you can call them from the PS command line. Must be full paths to the executable file.
    # ONLY EDIT THE PATH IN DOUBLE QUOTES. Note these are appended to the end of the path and will have lowest precedence.
        Set-Item -Path env:PATH -Value    ($env:PATH + ';' + "$env:USERPROFILE\Programs\7zip"        )    # adds 7-zip
        Set-Item -Path env:PATH -Value    ($env:PATH + ';' + "$env:USERPROFILE\Programs\notepad++"    )    # adds text editor (e.g., notepad++)
        Set-Item -Path env:PATH -Value    ($env:PATH + ';' + "$env:USERPROFILE\Programs\Firefox"        )    # adds browser (e.g., FireFox)

    # Set DEVHOME equal to each other if only 1 home is desired. These are used to validate certain abacus-related functions below.
        $DEVHOME1 = 'C:\eclipse\projects\'
        #$DEVHOME2 = 'C:\PSModules'

    # Shortcut to return to DEVHOME. Add a second Function for a DEVHOME2 If desired.
        Function dev    { Push-Location "$DEVHOME1" }
        Function pswork    { Push-Location "$DEVHOME2" }

    # Text editor alias. Requires the .exe path in your environment's $Path variable. See line 4 of this profile for an example with notepad++.
        $textEditorAlias = 'np'
        $textEditorExecutable = 'notepad++.exe'

#### End primary user-specific settings.
###########################################################################################################################

# Sets the default editor to notepad if $textEditorExecutable does not exist.
If ( !(Get-Command -Name $textEditorExecutable -ErrorAction SilentlyContinue) ) {
    $textEditorExecutable = 'notepad.exe'
}

# Alias for your text editor as chosen above.
Set-Alias -name $textEditorAlias -value $textEditorExecutable -scope Global -Option AllScope

# General Windows shortcuts
Function me         { Push-Location "$env:USERPROFILE" }
Function docs        { Push-Location "$env:USERPROFILE\Documents" }
Function dls        { Push-Location "$env:USERPROFILE\Downloads" }

Function hosts        { & $textEditorAlias 'C:\Windows\system32\drivers\etc\hosts' }

# Shortcut to fully qualified domain name
$FQDN = ([System.Net.Dns]::GetHostByName($env:computerName).HostName)

### Fixes the command line occassionally hanging (still testing this solution, got it from Stack)
powercfg -change -standby-timeout-ac 0

###########################################################################################################################

### PowerShell command line changes.

# Sets up tab autocomplete like in Unix
Set-PSReadlineKeyHandler    -Key Tab            -Function Complete

# Remove bell sound after tab complete
Set-PSReadlineOption        -BellStyle None

# up and down arrow keys navigate through history chain of commands.
Set-PSReadlineKeyHandler    -Key UpArrow        -Function PreviousHistory
Set-PSReadlineKeyHandler    -Key DownArrow        -Function NextHistory

# The next commands facilitate fast history searching. Highly convenient. Description:
### CTRL+up / down will skip through your history to commands that begin with your current command line input. Ex:
### cd C:/Users/me/Documents/myFolder
### gci
### run executable
### cd (CTRL + up) would autocomplete your command to the last command in history beginning with 'cd' --> cd C:/Users/me/Documents/myFolder
Set-PSReadlineKeyHandler -Key Ctrl+UpArrow        -Function HistorySearchBackward
Set-PSReadlineKeyHandler -Key Ctrl+DownArrow        -Function HistorySearchForward

Set-PSReadlineKeyHandler -Key Ctrl+u             -Function RevertLine            # Clears command line
Set-PSReadlineKeyHandler -Key Ctrl+e             -Function EndOfLine            # Navigates to end of line
Set-PSReadlineKeyHandler -Key Ctrl+w             -Function BeginningOfLine        # Navigates to beginning of line

# Set console colors

If ( (Get-Module PSReadLine | Select-Object -ExpandProperty Version) -ge [Version]'2.0' ) {

    Set-PSReadLineOption -Colors @{
        'Variable'                =    "$([char]0x1b)[38;2;115;195;255m"    
        'Operator'                =    "$([char]0x1b)[38;2;60;110;235m"        # Sets color of operators, e.g., =, ",", -match, -in, -lt/-gt, etc.
        'Comment'                =    "$([char]0x1b)[38;2;55;110;165m"    
        'ContinuationPrompt'            =    "$([char]0x1b)[38;2;115;195;55m"        # Color of the prompt character for multi-line commands
        'Member'                =    "$([char]0x1b)[38;2;255;166;77m"        # Object properties, such as "Path" from $variable.Path
        'Number'                =    "$([char]0x1b)[38;2;156;241;203m"    
        'Type'                    =    "$([char]0x1b)[38;2;204;51;255m"        # typing, e.g., [int] or [string] (brackets still colored by "default")
        'Command'                =    "$([char]0x1b)[38;2;255;255;102m"        # Sets the color of commands such as gci, cat, echo
        'Default'                =    "$([char]0x1b)[1;38;2;145;200;180m"        # Normal text and delimiters, e.g., () and {}
        'Keyword'                =    "$([char]0x1b)[38;2;203;1;67m"            # Sets the color of if or foreach, etc.
        'Error'                    =    "$([char]0x1b)[103;91m"            
        'Selection'                 =    "$([char]0x1b)[7m"                # Color of highlighting text with mouse.
        'String'                =    "$([char]0x1b)[38;2;215;215;180m"        # all strings, encased in either "" or ''
        'Parameter'                =    "$([char]0x1b)[38;2;255;155;195m"        # argument parameters, e.g., gci -Recurse (recurse is colored).
    }

    $promptLineColor = '[1;48;2;0;84;84;38;2;255;255;255m'

}
#List of default colors
#CommandColor                           : "$([char]0x1b)[93m"
#CommentColor                           : "$([char]0x1b)[32m"
#ContinuationPromptColor                : "$([char]0x1b)[33m"
#DefaultTokenColor                      : "$([char]0x1b)[33m"
#EmphasisColor                          : "$([char]0x1b)[96m"
#ErrorColor                             : "$([char]0x1b)[91m"
#KeywordColor                           : "$([char]0x1b)[92m"
#MemberColor                            : "$([char]0x1b)[97m"
#NumberColor                            : "$([char]0x1b)[97m"
#OperatorColor                          : "$([char]0x1b)[90m"
#ParameterColor                         : "$([char]0x1b)[90m"
#SelectionColor                         : "$([char]0x1b)[35;43m"
#StringColor                            : "$([char]0x1b)[36m"
#TypeColor                              : "$([char]0x1b)[37m"
#VariableColor                          : "$([char]0x1b)[92m"

###########################################################################################################################
###########################################################################################################################
###########################################################################################################################

### This section defines the prompt line formatting. For changing colors, see $promptLineColor above.

[System.Collections.Stack]$GLOBAL:profilePromptDirStack = @()
$GLOBAL:profilePromptOldPath = ''
$ESC = [char]27

Function prompt
{
    Set-Variable -Name countPSLine -Value ($countPSLine + 1) -Scope global
    If ( $countPSLine -gt 999 ) {
        Set-Variable -Name countPSLine -Value 0 -Scope global
    }
    If ( $PWD -match ".*\\.*\\.*\\.*\\.*\\" ) {
        $first = $(Get-Location).ToString().split('\')[0]
        $second = $(Get-Location).ToString().split('\')[1]
        $third = $(Get-Location).ToString().split('\')[-2]
        $fourth = $(Get-Location).ToString().split('\')[-1]
        if ($first.length    -gt 11    ) { $first    = $first.SubString(0,12) }
        if ($second.length    -gt 11    ) { $second    = $second.SubString(0,12) }
        if ($third.length    -gt 11    ) { $third    = $third.SubString($third.length - 12,12) }
        if ($fourth.length    -gt 15    ) { $fourth    = $fourth.SubString($fourth.length - 16,16) }

        $promptPath = ( $first + "\" + $second + "\....\" + $third + "\" + $fourth )
    }
    Else {
        $promptPath = $(Get-Location)
    }
    $PSVersion = ((Get-Host).Version.Major.ToString() + "." + (Get-Host).Version.Minor.ToString() + "." + (Get-Host).Version.Build.ToString() )
    
    "${ESC}${promptLineColor}" + $countPSLine + "|PS("+ $PSVersion + ") " + ($promptPath) + " [$(Get-Date -Format yyMMdd-HH:mm:ss)]>$ESC[0m "
    
    $GLOBAL:profilePromptNowPath = (Get-Location).Path
    
    If ($profilePromptNowPath -ne $profilePromptOldPath){
            $GLOBAL:profilePromptDirStack.Push($profilePromptOldPath)
            $GLOBAL:profilePromptOldPath = $profilePromptNowPath
        }

    return ' '
}

### Folder navigation Functions (cd, pushd, popd) set here

# This Function operates like a popd. It takes a numerical argument to move back a set number of directories.
Function bd {
    [CmdletBinding()]
    Param (
        [int]$level = 0
    )

    Set-Location (Get-Location -stack).Path[$level]
}

# Defines a Function equivalent to Unix's 'cd -'. We set the alias to 'cd-' for PowerShell.
Function cd- {
    Push-Location (Get-Location -stack).Path[1]
}

# cd has been redefined to pushd.
If ( [System.Environment]::OSVersion.Platform -notmatch 'unix' -and [System.Environment]::OSVersion.Platform -match 'Win' ) {
    Set-Alias -name cd -value Push-Location -option AllScope
}
Else {
    Set-Alias -name pd -value Push-Location -option AllScope
}
