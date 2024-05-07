function Get-PowerlineSymbols {
    $symbols = @'
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

    return $symbols | % { $_ + ' '}
}

<#
    $colorTerminal = '2;10;25;25m'

    #symbols
    
#    $beginPromptLineConnector = ''
#    $middlePromptLineConnector = ''
#    $endPromptLineConnector = ''

	$lightningBolt = [System.Text.Encoding]::Unicode.GetString(@(231,240))

#    $firstBlockColor = '2;150;30;65m'
#    $firstBlockOpeningSymbol =

    # Defining ansi color/formatting variables that are used later
    $ANSI = [char]27

    $colorForeFullWhite = "$ANSI[1;38;2;255;255;255m"
    $colorForeBrightCyan = "$ANSI[1;38;2;40;255;255m"
    $colorForeYellow = "$ANSI[93m"
    $colorForeGray = "$ANSI[37m"
    $colorForeRed = "$ANSI[91m"
    $colorForeGreen = "$ANSI[92m"
    $colorForeOrange = "$ANSI[38;5;202m"
    
    $colorBackYellow = "$ANSI[103m"
    
    $boldText = "$ANSI[1m"
    $dimText = "$ANSI[2m"
    $italicizeText = "$ANSI[3m"
    $underlineText = "$ANSI[4m"
    $blinkText = "$ANSI[5m"
    $reverseText = "$ANSI[7m"
    $hideText = "$ANSI[8m"
    $strikeText = "$ANSI[9m"
    
    $undoBoldText = $undoDimText = "$ANSI[22m"
    $undoItalicizeText = "$ANSI[23m"
    $undoUnderlineText = "$ANSI[24m"
    $undoBlinkText = "$ANSI[25m"
    $undoReverseText = "$ANSI[27m"
    $undoHideText = "$ANSI[28m"
    $undoStrikeText = "$ANSI[29m"

    #resetPromptColor deactivates all ASCII formatting.
	$resetPromptColor = "$ANSI[0m"
	
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
<#
    
    $defaultColorBack = '{0}{1}' -f "$ANSI[1;48;", $colorTerminal
    $defaultColorFore = '{0}{1}' -f "$ANSI[1;38;", $colorTerminal

    $markColor = '2;150;30;65m'
	$markColorBack = '{0}{1}' -f "$ANSI[1;48;", $markColor
    $markColorFore = '{0}{1}' -f "$ANSI[1;38;", $markColor
	$markStart  = '{0}{1}{2}'   -f $defaultColorBack, $markColorFore,   ''
    $markBody   = '{0}{1}'      -f $markColorBack   , $colorForeFullWhite
	$markEnd    = '{0}{1}{2}'   -f $defaultColorBack, $markColorFore,   ''
	
    $versionColor = '2;20;90;169m'
    $versionColorFore = '{0}{1}' -f "$ANSI[1;38;", $versionColor
    $versionColorBack = '{0}{1}' -f "$ANSI[1;48;", $versionColor
	$versionStart	= '{0}{1}{2}' -f $versionColorBack, $defaultColorFore, ''
    $versionBody	= '{0}{1}{2}' -f $versionColorBack, $colorForeFullWhite, '💪🐚'
	$versionEnd     = '{0}{1}{2}' -f $defaultColorBack, $versionColorFore, ''

    $timestampColor = '2;210;140;40m'
    $timestampColorFore = '{0}{1}'  -f "$ANSI[1;38;", $timestampColor
    $timestampColorBack = '{0}{1}'  -f "$ANSI[1;48;", $timestampColor
	$timestampStart	= '{0}{1}{2}'   -f  $timestampColorBack, $defaultColorFore, ''
	$timestampBody	= '{0}{1}'      -f  $timestampColorBack, $colorForeFullWhite	
    $timestampEnd	= '{0}{1}{2}'   -f $defaultColorBack, $timestampColorFore, ''
	
    $locationColor = '2;40;169;120m'
    $locationColorBack = '{0}{1}' -f "$ANSI[1;48;", $locationColor
    $locationColorFore = '{0}{1}' -f "$ANSI[1;38;", $locationColor
	$locationStart  = '{0}{1}{2}'   -f $locationColorBack, $defaultColorFore, ''
    $locationBodyColor   = '{0}{1}'   -f $locationColorBack, $colorForeFullWhite
    $locationBody   = '{0}{1}{2}'   -f $locationColorBack, $colorForeFullWhite, '📂'
	$locationEnd    = '{0}{1}{2}'   -f $defaultColorBack, $locationColorFore,  ''

    $branchColor = '2;170;70;235m'
	$branchColorBack = '{0}{1}' -f "$ANSI[1;48;", $branchColor
    $branchColorFore = '{0}{1}' -f "$ANSI[1;38;", $branchColor

	$branchStart  = '{0}{1}{2}' -f $branchColorBack , $defaultColorFore,   ''
    $branchBody   = '{0}{1}'    -f $branchColorBack , $colorForeBrightCyan
	$branchEnd    = '{0}{1}{2}' -f $defaultColorBack, $branchColorFore,    ''

###########################################################################################################################
###########################################################################################################################
###########################################################################################################################

# Define some static variables before beginning the prompt function.
$pwshVersion = $PSVersionTable.PSVersion.ToString()
$dirSep = [IO.Path]::DirectorySeparatorChar
$regExDirSep = [Regex]::Escape($dirSep)

#prompt is a function called by powershell after every command. Its output defines the prompt line.
#All content that must be recalculated after every command goes into the body of the prompt function.
<#
Function prompt {
    # Checks the outcome of the previous command and defines some emojis based on that. These are placed at the start and end of the prompt line later.
	$lastStatus, $currentConfidenceInProgrammingSkillz = & {
		If ($?) {	'🏄', (' {0}{1}' -f $colorForeGreen, $resetPromptColor)}
		Else { '🔥', ('🦨{0}{1}' -f $colorForeOrange, $resetPromptColor)}
        
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
				$forceShowDir = '{0}{1}{2}{3}prod{4}{5}' -f $colorForeFullWhite, $underlineText, $colorBackYellow, $colorForeRed, $resetPromptColor, $locationBodyColor
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
                    '{0}  {1}{2}{3}{4}{5}{6}' -f $colorForeYellow, $resetPromptColor, $branchBody, $colorForeBrightCyan, $underlineText, $branchName.ToUpper(), $resetPromptColor
                }
                Else {'{0}  {1}{2}{3}{4}{5}' -f $colorForeGray, $resetPromptColor, $branchBody, $colorForeBrightCyan, $branchName, $resetPromptColor}
            }
            $promptBranch = '{0}{1}{2}{3}' -f $branchStart, $branchBody, $branchState, $branchEnd
        }
        Else { $promptBranch = $null }
    }
    else { $promptBranch = $null }
    # The remaining components are finalized here. Their logic has already been derived in code further up.
	$promptMark		= '{0}{1}{2}{3}' -f $markStart, $markBody, $lastStatus, $markEnd
    $promptVersion	= '{0}{1}{2}{3}' -f $versionStart, $versionBody, $pwshVersion, $versionEnd
    $promptStamp	= '{0}{1}{2} {3}{4}' -f $timestampStart, $timestampBody, $timestamp, $mood, $timestampEnd
    $promptFolder	= ('{0}{1} {2}{3}' -f $locationStart, $locationBody, $currentLoc, $locationEnd) -replace '\\','/'

    $length = ($promptMark + $promptVersion + $promptStamp + $promptFolder + $promptBranch + $resetPromptColor + $currentConfidenceInProgrammingSkillz).length
    # The final prompt line design, concatenating all the prompt variables together.
	[Environment]::NewLine + [char]0x0250C + $promptMark + $promptVersion + $promptStamp + $promptFolder + $promptBranch + $resetPromptColor + $currentConfidenceInProgrammingSkillz + [Environment]::NewLine + [char]0x02514

    try {
        $area = (gkc).Name
        $ns = (gkc).Namespace
        [string]$nsNumber = [Kube]::MapIntsToNamespaces.GetEnumerator() | Where-Object Value -eq $ns | Select -exp Name
        if ( $area ) {
            $originalHostForegroundColor = $host.UI.RawUI.ForegroundColor
            $startposx = $Host.UI.RawUI.windowsize.width - ($area.length + $ns.length + 2 + $nsNumber.length + 3 )
            $startposy = $Host.UI.RawUI.CursorPosition.Y
            $host.UI.RawUI.ForegroundColor = 'Red'
            $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates $startposx,$startposy
            $Host.UI.Write("${area}: $ns ($nsNumber)")
            $host.UI.RawUI.ForegroundColor = $originalHostForegroundColor
        }
    } catch {}
    # Adds an extra empty line after the output of every command.
    return ' '
}
#>
