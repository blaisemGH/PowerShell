### PowerShell command line changes.

# Sets up tab autocomplete like in Unix
Set-PSReadlineKeyHandler	-Key Tab			-Function MenuComplete

# Remove bell sound after tab complete
Set-PSReadlineOption		-BellStyle None

# up and down arrow keys navigate through history chain of commands.
Set-PSReadlineKeyHandler	-Key UpArrow		-Function PreviousHistory
Set-PSReadlineKeyHandler	-Key DownArrow		-Function NextHistory

# The next commands facilitate fast history searching. Highly convenient.
Set-PSReadlineKeyHandler    -Key Ctrl+UpArrow	-Function HistorySearchBackward
Set-PSReadlineKeyHandler    -Key Ctrl+DownArrow	-Function HistorySearchForward

Set-PSReadlineKeyHandler    -Key Ctrl+u 		-Function RevertLine			# Clears command line
Set-PSReadlineKeyHandler    -Key Ctrl+e 		-Function EndOfLine				# Navigates to end of line

#List of default PSReadLine colors
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

# Set console colors if PSReadLine is at least version 2. See the defaults above to reset them.

If ( (Get-Module PSReadLine | Select-Object -ExpandProperty Version) -ge [Version]'2.0' ) {

	Set-PSReadLineOption -Colors @{
'Variable'			=	"$([char]0x1b)[38;2;115;195;255m"
'Operator'			=	"$([char]0x1b)[38;2;60;110;235m"	# Sets color of operators, e.g., =, -match, -in, -lt/-gt, etc.
'Comment'			=	"$([char]0x1b)[38;2;55;110;165m"
'ContinuationPrompt'=	"$([char]0x1b)[38;2;115;195;55m"	# Color of the prompt character for multi-line commands
'Member'			=	"$([char]0x1b)[38;2;255;166;77m"	# Object properties, such as "Path" from $variable.Path
'Number'			=	"$([char]0x1b)[38;2;156;241;203m"
'Type'				=	"$([char]0x1b)[38;2;204;51;255m"	# typing, e.g., [int], [string] (bracket color still "default")
'Command'			=	"$([char]0x1b)[38;2;255;255;102m"	# Sets the color of commands such as gci, cat, echo
'Default'			=	"$([char]0x1b)[1;38;2;145;200;180m"	# Normal text and delimiters, e.g., () and {}
'Keyword'			=	"$([char]0x1b)[38;2;203;1;67m"		# Sets the color of if or foreach, etc.
'Error'				=	"$([char]0x1b)[103;91m"
'Selection' 		=	"$([char]0x1b)[7m"					# Color of highlighting text with mouse.
'String'			=	"$([char]0x1b)[38;2;215;215;180m"	# all strings, encased in either "" or ''
'Parameter'			=	"$([char]0x1b)[38;2;255;155;195m"	# argument parameters, e.g., gci -Recurse (recurse is colored).
	}
}

# Sets a default template
if ( [PSPromptConfig]::PromptConfigsLeft.Count -lt 1 ) {
    [PSPromptConfig]::PromptConfigsLeft.Add(-1 , 
        ([PSPrompt]@{
            Content = { $PWD.Path + ' ' }
        })
    )
}
<# Add in formatting to place these on the next line.
        ╭
        │
        ╰
        ┌
        │
        └
        [char]0x0250C = ┌ ; [char]0x02514 = └; [char]8739 = │; [char]0x0256d = ╭; [char]0x02570 = ╰
        Defaults all to empty if SetMultilineConnector is not run.
        Copy this line into your profile to set:
            [PSPromptConfig]::SetMultilineConnector([char]0x0256d, [char]0x02502, [char]0x02570)
        Note this is automatically set if right alignment items are added.
#>

$localConfigDir = "$HOME/.pwsh/PSPrompt"

if (!(Test-Path $localConfigDir/templates.ps1)) {
    New-Item -ItemType Directory -Path $localConfigDir -ErrorAction SilentlyContinue -Force
    Copy-Item $PSScriptRoot/templates.ps1 $localConfigDir/templates.ps1
}