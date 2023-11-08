### PowerShell command line changes.

# Sets up tab autocomplete like in Unix
Set-PSReadlineKeyHandler	-Key Tab			-Function Complete

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
Set-PSReadlineKeyHandler    -Key Ctrl+w 		-Function BeginningOfLine		# Navigates to beginning of line

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

    # Defining ascii color/formatting variables that are used later
    $ESC = [char]27
    $colorForeYellow = "$ESC[93m"
    $colorForeWhite = "$ESC[1m"
    $colorForeGray = "$ESC[37m"
    $colorForeRed = "$ESC[91m"
    $colorForeGreen = "$ESC[92m"
    
    $colorBackYellow = "$ESC[103m"
    
    $underlineText = "$ESC[4m"
    
	<#
        The below colors/formats are divided into the different components of the prompt line:
            • "mark" component that displays the current line state
            • "version" component that displays the PS version
            • "stamp" component that displays the current timestamp
            • "folder" component that displays the current filepath
            • "branch" component that displays the current branch in github.
        
        Each component is further divided into 3 variables:
            • "color" is the color of the entire component on the prompt
            • "start" is the opening character for that component
            • "end" is the last character for that component.
    #>
    
	$markColor = "$ESC[1;48;2;150;30;65;38;2;255;255;255m"
	$markStart = "$ESC[1;48;2;10;25;25;38;2;150;30;65m"
	$markEnd = "$ESC[1;48;2;10;25;25;38;2;150;30;65m"
	
    $versionColor	= "$ESC[3;48;2;20;90;169;38;2;255;255;255m💪🐚"
	$versionStart	= "$ESC[1;48;2;20;90;169;38;2;10;25;25m$ESC[0m"
	$versionEnd	= "$ESC[0m$ESC[1;48;2;10;25;25;38;2;20;90;169m"

	$stampColor	= "$ESC[1;48;2;210;140;40;38;2;255;255;255m"	
	$stampStart	= "$ESC[1;48;2;210;140;40;38;2;10;25;25m"
	$stampEnd	= "$ESC[1;48;2;10;25;25;38;2;210;140;40m"
	
	$folderColor	= "$ESC[1;48;2;40;169;120;38;2;255;255;255m"
	$folderIcon		= '📂'
	$folderStart	= "$ESC[1;48;2;40;169;120;38;2;10;25;25m"
	$folderEnd	= "$ESC[1;48;2;10;25;25;38;2;40;169;120m"

	$branchColor = "$ESC[1;48;2;170;70;235;38;2;40;255;255m"
	$branchStart = "$ESC[1;48;2;180;0;255;38;2;10;25;25m"
	$branchEnd = "$ESC[1;48;2;10;25;25;38;2;180;0;255m"

    #endPromptColor deactivates all ASCII formatting.
	$endPromptColor = "$ESC[0m"
	$lightningBolt = [System.Text.Encoding]::Unicode.GetString(@(231,240))
    
    # A list of symbols from powerline that can be copied for your own customizations.
	$powerlineSymbols = @'
⏻⏼⏽⏾⭘




























♥⚡






'@
}

###########################################################################################################################
###########################################################################################################################
###########################################################################################################################

# Define some static variables before beginning the prompt function.
$pwshVersion = $PSVersionTable.PSVersion.ToString()
$dirSep = [IO.Path]::DirectorySeparatorChar
$regExDirSep = [Regex]::Escape($dirSep)

#prompt is a function called by powershell after every command. Its output defines the prompt line.
#All content that must be recalculated after every command goes into the body of the prompt function.
Function prompt {
    # Checks the outcome of the previous command and defines some emojis based on that. These are placed at the start and end of the prompt line later.
	$lastStatus, $currentConfidenceInProgrammingSkillz = & {
		If ($?) {	'💰', (' {0}{1}' -f $colorForeGreen, $endPromptColor)}
		Else { '💔', (' 🚽{0}{1}' -f $colorForeRed, $endPromptColor)}
	}
    # I count the number of commands entered into a session, because I can.
	Set-Variable -Name countPSLine -Value ($countPSLine + 1) -Scope global
	If ( $countPSLine -gt 999 ) {
		Set-Variable -Name countPSLine -Value 0 -Scope global
	}

    # $currentLoc derives the current filepath.
    # It trims filepaths to a fixed max length, and if there are more than 4 directories in the filepath, the additional folders are replaced with a duck emoji.
    # These settings keep the prompt line from stretching across the console due to huge filepaths.
	$currentLoc = & {
		If ( $PWD -match ".*$regExDirSep.*$regExDirSep.*$regExDirSep.*$regExDirSep.+" ) { # check if more than 4 directories
			$pwdAsDirArray = (Get-Location).ToString().split($dirSep)
			$thirdLast = $pwdAsDirArray[-3]
			$secondLast = $pwdAsDirArray[-2]
			$last = $pwdAsDirArray[-1]
            # caps the length of each folder
			if ($thirdLast.length	-gt 11	) { $thirdLast	= $thirdLast.SubString(0,12) }
			if ($secondLast.length	-gt 15	) { $secondLast	= $secondLast.SubString(0,16) }
			if ($last.length	-gt 15	) { $last	= $last.SubString($last.length - 16,16) }

            # checks for the string prod and highlights it.
            # I use this with git as a reminder, so I don't accidentally edit prod code.
			If ( $pwdAsDirArray -Contains 'prod' ) {
				$forceShowDir = '{0}{1}{2}{3}prod{4}{5}' -f $colorForeWhite, $underlineText, $colorBackYellow, $colorForeRed, $endPromptColor, $folderColor
				If ( $thirdLast -ne 'prod' ) {
					$forceShowDir = $forceShowDir + '/🦆'
				}
				$thirdLast = $forceShowDir
			}
            # The output trimmed current path.
			$PWD.Drive.Root + '🦆' + $dirSep + $thirdLast + $dirSep + $secondLast + $dirSep + $last
		}
		Else {
            # If 4 directories or fewer, just output the path as normal.
			Get-Location
		}
	}

    # Timestamp used in the timestamp component
	$newTimestamp = Get-Date
	$timestamp = Get-Date $newTimestamp -Format HH:mm:ss
    
    # Mood configures smiley faces next to your timestamp based on the day of the week or time of day.
	$mood = & {
		Switch ( $newTimestamp.DayOfWeek ) {
			'Friday' { '🤗'}
			'Saturday' { '😨'}
			'Sunday' { '😨'}
			DEFAULT {
				Switch ($newTimestamp.Hour) {
					{ $_ -lt 10 } { '🥱' }
					{ $_ -gt 18 } { '😵' }
					{ $_ -ge 10 -and $_ -lt 15 } { '😏'}
					DEFAULT { '😜'}
				}
			}
		}
	}

    # The below "prompt" variables concatenate all of the above-defined variables and colors into a single variable containing the definition of a component's final appearance in the prompt.
    # First the branch component for git is finalized.
    if ( Get-Command git ) {
        $branchName = git branch --show-current
        If ( $? ) {
            $branchState = & {
                If ( $branchName -in 'main', 'master' ) {
                    '{0}  {1}{2}{3}{4}{5}{6}' -f $colorForeYellow, $endPromptColor, $branchColor, $colorForeWhite, $underlineText, $branchName.ToUpper(), $endPromptColor
                }
                Else {'{0}  {1}{2}{3}{4}{5}' -f $colorForeGray, $endPromptColor, $branchColor, $colorForeWhite, $branchName, $endPromptColor}
            }
            $promptBranch = '{0}{1}{2}{3}' -f $branchStart, $branchColor, $branchState, $branchEnd
        }
        Else { $promptBranch = $null }
    }
    else { $promptBranch = $null }
    # The remaining components are finalized here. Their logic has already been derived in code further up.
	$promptMark		= '{0}{1}{2}{3}' -f $markStart, $markColor, $lastStatus, $markEnd
	$promptVersion	= '{0}{1}{2}{3}' -f $versionStart, $versionColor, $pwshVersion, $versionEnd
	$promptStamp	= '{0}{1}{2} {3}{4}' -f $stampStart, $stampColor, $timestamp, $mood, $stampEnd
	$promptFolder	= ('{0}{1}{2} {3}{4}' -f $folderStart, $folderColor, $folderIcon, $currentLoc, $folderEnd) -replace '\\','/'
	
    # The final prompt line design, concatenating all the prompt variables together.
	[Environment]::NewLine + $promptMark + $promptVersion + $promptStamp + $promptFolder + $promptBranch + $endPromptColor + $currentConfidenceInProgrammingSkillz
	
    # Adds an extra empty line after the output of every command.
    return ' '
}

Export-ModuleMember -Function Prompt