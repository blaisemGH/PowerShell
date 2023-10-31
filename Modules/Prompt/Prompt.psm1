### PowerShell command line changes.

# Sets up tab autocomplete like in Unix
Set-PSReadlineKeyHandler	-Key Tab			-Function Complete

# Remove bell sound after tab complete
Set-PSReadlineOption		-BellStyle None

# up and down arrow keys navigate through history chain of commands.
Set-PSReadlineKeyHandler	-Key UpArrow		-Function PreviousHistory
Set-PSReadlineKeyHandler	-Key DownArrow		-Function NextHistory

# The next commands facilitate fast history searching. Highly convenient.
Set-PSReadlineKeyHandler -Key Ctrl+UpArrow		-Function HistorySearchBackward
Set-PSReadlineKeyHandler -Key Ctrl+DownArrow	-Function HistorySearchForward

Set-PSReadlineKeyHandler -Key Ctrl+u 			-Function RevertLine			# Clears command line
Set-PSReadlineKeyHandler -Key Ctrl+e 			-Function EndOfLine				# Navigates to end of line
Set-PSReadlineKeyHandler -Key Ctrl+w 			-Function BeginningOfLine		# Navigates to beginning of line

# Set console colors

If ( (Get-Module PSReadLine | Select-Object -ExpandProperty Version) -ge [Version]'2.0' ) {

	Set-PSReadLineOption -Colors @{
		'Variable'				=	"$([char]0x1b)[38;2;115;195;255m"	
		'Operator'				=	"$([char]0x1b)[38;2;60;110;235m"		# Sets color of operators, e.g., =, ",", -match, -in, -lt/-gt, etc.
		'Comment'				=	"$([char]0x1b)[38;2;55;110;165m"	
		'ContinuationPrompt'	=	"$([char]0x1b)[38;2;115;195;55m"		# Color of the prompt character for multi-line commands
		'Member'				=	"$([char]0x1b)[38;2;255;166;77m"		# Object properties, such as "Path" from $variable.Path
		'Number'				=	"$([char]0x1b)[38;2;156;241;203m"	
		'Type'					=	"$([char]0x1b)[38;2;204;51;255m"		# typing, e.g., [int] or [string] (brackets still colored by "default")
		'Command'				=	"$([char]0x1b)[38;2;255;255;102m"		# Sets the color of commands such as gci, cat, echo
		'Default'				=	"$([char]0x1b)[1;38;2;145;200;180m"		# Normal text and delimiters, e.g., () and {}
		'Keyword'				=	"$([char]0x1b)[38;2;203;1;67m"			# Sets the color of if or foreach, etc.
		'Error'					=	"$([char]0x1b)[103;91m"			
		'Selection' 			=	"$([char]0x1b)[7m"						# Color of highlighting text with mouse.
		'String'				=	"$([char]0x1b)[38;2;215;215;180m"		# all strings, encased in either "" or ''
		'Parameter'				=	"$([char]0x1b)[38;2;255;155;195m"		# argument parameters, e.g., gci -Recurse (recurse is colored).
	}

	$promptLineColor= '[1;48;2;0;84;84;38;2;255;255;255m'
	$ESC = [char]27
	$backgroundPromptColor = "$ESC[1;48;2;10;25;25"
	$break = "$ESC[1;48;2;10;25;25;38;2;10;25;25m"
	$markColor = "$ESC[1;48;2;150;30;65;38;2;255;255;255m"#"
	$markStart = "$ESC[1;48;2;10;25;25;38;2;150;30;65m"
	$markEnd = "$ESC[1;48;2;10;25;25;38;2;150;30;65m"
	$versionColor	= "$ESC[3;48;2;20;90;169;38;2;255;255;255m💪🐚"
	#$versionReverse	= "$ESC[1;48;2;0;0;0;38;2;20;90;169m"
	$versionStart	= "$ESC[1;48;2;20;90;169;38;2;10;25;25m$ESC[0m"
	$versionEnd	= "$ESC[0m$ESC[1;48;2;10;25;25;38;2;20;90;169m"

	$stampColor	= "$ESC[1;48;2;210;140;40;38;2;255;255;255m"	
	$stampStart	= "$ESC[1;48;2;210;140;40;38;2;10;25;25m"
	$stampEnd	= "$ESC[1;48;2;10;25;25;38;2;210;140;40m"
	
	$folderColor	= "$ESC[1;48;2;40;169;120;38;2;255;255;255m"
	$folderIcon		= '📂'
	#$folderIcon	= "$ESC[31m $folderColor"
	$folderStart	= "$ESC[1;48;2;40;169;120;38;2;10;25;25m"
	$folderEnd	= "$ESC[1;48;2;10;25;25;38;2;40;169;120m"
	#$folderEnd	= "$ESC[1;48;2;0;0;0;38;2;200;169;20m"

	#$branchColor = "$ESC[1;48;2;180;0;255;38;2;40;255;255m"
	$branchColor = "$ESC[1;48;2;170;70;235;38;2;40;255;255m"
	$branchStart = "$ESC[1;48;2;180;0;255;38;2;10;25;25m"
	$branchEnd = "$ESC[1;48;2;10;25;25;38;2;180;0;255m"

	$endPromptColor = "$ESC[0m"
	$sep2 = [char]::ConvertFromUtf32(0x276F)
	$sep = [System.Text.Encoding]::Unicode.GetString(@(176,224)) #[char]::convertFromUtf32(0xe0b0)
	$lightningBolt = [System.Text.Encoding]::Unicode.GetString(@(231,240))
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
#$script:oldTimestamp = Get-Date
$pwshVersion = $PSVersionTable.PSVersion.ToString()
$dirSep = [IO.Path]::DirectorySeparatorChar
$regExDirSep = [Regex]::Escape($dirSep)
Function prompt {
	$lastStatus, $currentConfidenceInProgrammingSkillz = & {
		If ($?) {	'💰', " $ESC[92m$endPromptColor" }
		Else { '💔', " 🚽$ESC[91m$endPromptColor" } #
	}
	Set-Variable -Name countPSLine -Value ($countPSLine + 1) -Scope global
	If ( $countPSLine -gt 999 ) {
		Set-Variable -Name countPSLine -Value 0 -Scope global
	}

	$currentLoc = & {
		If ( $PWD -match ".*$regExDirSep.*$regExDirSep.*$regExDirSep.*$regExDirSep.+" ) {
			$pwdAsDirArray = (Get-Location).ToString().split($dirSep)
			$thirdLast = $pwdAsDirArray[-3]
			$secondLast = $pwdAsDirArray[-2]
			$last = $pwdAsDirArray[-1]
			if ($thirdLast.length	-gt 11	) { $thirdLast	= $thirdLast.SubString(0,12) }
			if ($secondLast.length	-gt 15	) { $secondLast	= $secondLast.SubString(0,16) }
			if ($last.length	-gt 15	) { $last	= $last.SubString($last.length - 16,16) }

			If ( $pwdAsDirArray -Contains 'prod' ) {
				$forceShowDir = "$ESC[1m$ESC[4m$ESC[103m$ESC[91mprod$endPromptColor$folderColor"
				If ( $thirdLast -ne 'prod' ) {
					$forceShowDir = $forceShowDir + '/🦆'#'/'
				}
				$thirdLast = $forceShowDir
			}
			$PWD.Drive.Root + '🦆' + $dirSep + $thirdLast + $dirSep + $secondLast + $dirSep + $last #''
		}
		Else {
			Get-Location
		}
	}

	$newTimestamp = Get-Date
	#$elapsed = (($newTimestamp - $oldTimestamp).ToString() -replace '00:' -replace '.{5}$').Trim('0')
	#$script:oldTimestamp = $newTimestamp
	$timestamp = Get-Date $newTimestamp -Format HH:mm:ss
	$mood = & {
		Switch ( $newTimestamp.DayOfWeek ) {
			'Friday' { '🤗'}#'' }
			'Saturday' { '😨'}#'' }
			'Sunday' { '😨'}#'' }
			DEFAULT {
				Switch ($newTimestamp.Hour) {
					{ $_ -lt 10 } { '🥱' }
					{ $_ -gt 18 } { '😵' }
					{ $_ -ge 10 -and $_ -lt 15 } { '😏'}#'' }
					DEFAULT { '😜'}#'' }
				}
			}
		}
	}

	$branchName = & git branch --show-current
	If ( $? ) {
		$branchState = & {
			If ( $branchName -in 'main', 'master' ) {
				"$ESC[93m  $ESC[0m$branchColor$ESC[1m$ESC[4m$($branchName.ToUpper())$endPromptColor"#[46m$ESC[101m$branchName$endPromptColor"
			}
			Else {"$ESC[37m  $ESC[0m$branchColor$ESC[1m$branchName$endPromptColor"}
		}
		$promptBranch = "$branchStart$branchColor$branchState$branchEnd"
	}
	Else { $promptBranch = $null }
	$promptMark		= "$markStart$markColor$lastStatus$markEnd"
	$promptVersion	= "$versionStart$versionColor$pwshVersion$versionEnd"
	$promptStamp	= "$stampStart$stampColor$timestamp $mood$stampEnd"
	$promptFolder	= "$folderStart$folderColor$folderIcon $currentLoc$folderEnd" -replace '\\','/'
	#"${ESC}${promptLineColor}" + $countPSLine + '| ' + [char]::ConvertFromUtf32(0x1F4AA) + "($PSVersion)"	+ ' ' + [char]::ConvertFromUtf32(0x1F5BF) + $promptPath + ' ' + [char]::ConvertFromUtf32(0x1F4C5) + "[$()]>$ESC[0m "
	#"${ESC}${promptLineColor} " + $countPSLine + ' ' + $lastStatus + ' ' + "($PSVersion)"	+ ' (' + $promptPath + ') ' + "[$timestamp] $elapsed $ESC[0m  "
	
	[Environment]::NewLine + $promptMark + $promptVersion + $promptStamp + $promptFolder + $promptBranch + $endPromptColor + $currentConfidenceInProgrammingSkillz
	$GLOBAL:profilePromptNowPath = (Get-Location).Path
	If($profilePromptNowPath -ne $profilePromptOldPath){
        $GLOBAL:profilePromptDirStack.Push($profilePromptOldPath)
        $GLOBAL:profilePromptOldPath = $profilePromptNowPath
    }
	
    return ' '
}

Export-ModuleMember -Function Prompt