if ( $env:NerdFont ) {
[PSPromptConfig]::NoItemsOnLastLine = $true
[PSPromptConfig]::DefaultPromptBeckon = ''
[PSPromptConfig]::SetMultilineConnector()
#[PSPromptConfig]::SetSpaceBetweenItemSeparators(1, '10;25;25')
[PSPromptConfig]::UseDefaultGroupMarkers('Left')

$getRunDuration = {
    $history = Get-History
    $fmtDuration = if ( $history ) {
        try {
            $duration = $d = $history[-1].Duration
            switch ($duration) {
                {$_.Days} { '{0}d {1}h{2}m{3}.{4}s' -f $d.Days, $d.Hours, $d.Minutes, $d.Seconds, $d.Milliseconds; break }
                {$_.Hours} { '{0}h{1}m{2}.{3}s' -f $d.Hours, $d.Minutes, $d.Seconds, $d.Milliseconds; break }
                {$_.Minutes} {'{0}m{1}.{2}s' -f $d.Minutes, $d.Seconds, $d.Milliseconds; break }
                {$_.Seconds} {'{0}.{1}s' -f $d.Seconds, $d.Milliseconds }
                DEFAULT { '{0}ms' -f $d.Milliseconds }
            }
        } catch {}
    }
    return '' + $fmtDuration
}
$promptTemplateGetRunDuration = @{
    Alignment = 'Left'
    ItemSeparator = ''
    BackgroundColor = '150;30;65'
    ContentFunction = $getRunDuration
}
Add-PSPromptTemplateItem @promptTemplateGetRunDuration


$getPSVersion = { 'PS' + $PSVersionTable.PSVersion.ToString() + ' ' }
$promptTemplateGetPSVersion = @{
    Alignment = 'Left'
    ItemSeparator = ''
    AnsiEffects = 'italicize'
    BackgroundColor = '20;90;169'
    ContentFunction = $getPSVersion
    DoNotRecalculateContentValue = $true
}
Add-PSPromptTemplateItem @promptTemplateGetPSVersion


$getPromptTimestamp = { return (Get-Date).ToString('HH:mm:ss') }
$promptTemplateGetTimestamp = @{
    Alignment = 'Left'
    ItemSeparator = ''
    BackgroundColor = '210;140;40'
    ContentFunction = $getPromptTimestamp
}
Add-PSPromptTemplateItem @promptTemplateGetTimestamp


$itemCurrentPath = {
    param($ansi)
    $dirSep = [IO.Path]::DirectorySeparatorChar
    $regExDirSep = [Regex]::Escape($dirSep)
    $driveSep = if ( $env:OS -match 'Windows' ) { ':' } else {$null}
    If ( Get-Command git ) {
        $rootDir = git rev-parse --show-toplevel
        if ( $rootDir ) {
            $repoDir = (Split-Path $rootDir -Leaf) + $driveSep
            $regexRootDir = [regex]::Escape($rootDir)
        }
    }
    $currentPath = $PWD.Path -replace [regex]::Escape($HOME), '~' -replace $regExDirSep, '/' -replace $regexRootDir, $repoDir
    $driveRoot = $PWD.Drive.Name + $driveSep + "$dirSep"

    If ( $currentPath -match ".*$regExDirSep.*$regExDirSep.*$regExDirSep.*$regExDirSep.+" ) { # check if more than 4 directories
        $pwdAsDirArray = $currentPath.split($dirSep)
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
            $forceShowDir = "`e[91;103m" + 'prod' + $ansi
            If ( $thirdLast -ne 'prod' ) {
                $forceShowDir = $forceShowDir + '\...'
            }
            $thirdLast = $forceShowDir
        }
        # The output trimmed current path.
        ('📂 ' + $driveRoot + '...' + $dirSep + $thirdLast + $dirSep + $secondLast + $dirSep + $last) -replace '\\', '/'
    }
    Else {
        # If 4 directories or fewer, just output the path as normal.
        ('📂 ' + $currentPath) -replace '\\','/'
    }

    #('📂 ' + $currentPath) -replace '\\','/'
}

$promptTemplateGetCurrentPath = @{
    Alignment = 'Left'
    ItemSeparator = ''
    BackgroundColor = '40;169;120'
    ContentFunction = $itemCurrentPath
}
Add-PSPromptTemplateItem @promptTemplateGetCurrentPath


if ( Get-Command git ) {
    $getGitBranch = {
        param($ansi)
        $branchName = git branch --show-current
        If ( $? ) {
            If ( $branchName -in 'main', 'master' ) {
                $out = " `e[0m`e[93m " + $ansi + $branchName
                $parent = $branchName
            }
            Else {
                $out = " `e[0m`e[37m " + $ansi + $branchName
                $parent = & {
                    if ( $branchName -match '^(develop|release)$') {
                        try {(git branch | Select-String '^\s*(main|master)$' | Sort-Object | Select-Object -First 1).Line.Trim()} catch {$branchName}
                    }
                    else {
                        try {
                            (git branch | Select-String develop | Sort-Object | Select-Object -First 1).Line.Trim()
                        }
                        catch {
                            (git branch | Select-String '^\s*(main|master)$' | Sort-Object | Select-Object -First 1).Line.Trim()
                        }
                    }
                }
            }
        }
        if ( $out ) {
            $relativeCommits = (git rev-list --left-right --count origin/$parent...origin/$branchName ) -split '\s+'
            $commitsBehind = if ( $relativeCommits[0] ) { "`e[91m$($relativeCommits[0])" }
            $commitsAhead = if ( $relativeCommits[1] ) { "`e[32m$($relativeCommits[1])" }
            $null = try {git log --oneline -n 50 --decorate=short | % { if ( $_ -match '^([a-zA-Z0-9]+) \((\S+)\)' ) { return } } } catch {}
            $out += " $commitsBehind $commitsAhead `e[0m $ansi"
        }
        return $out
    }
}
$promptTemplateGetGitBranch = @{
    Alignment = 'Left'
    NoGroup = $true
    LineToPrintOn = 2
    ForegroundColor = 'Orchid'
    ContentFunction = $getGitBranch
    AnsiEffects = 'italicize'
}

Add-PSPromptTemplateItem @promptTemplateGetGitBranch
} else {
    [PSPromptConfig]::MultiLineConnectorOpenDefaults = @{
        FirstLine = ''
        MiddleLine = ''
        LastLine = '--'
    }
    $isZsh = if ($env:SHELL -match 'zsh') { $true }

    $getPSVersion = { 'PS ' + $PSVersionTable.PSVersion.ToString() + ' ' }
    $promptTemplateGetPSVersion = @{
        Alignment = 'Left'
        AnsiEffects = 'italicize'
        ForegroundColor = '20;90;169'
        ContentFunction = $getPSVersion
        DoNotRecalculateContentValue = $true
    }
    if ($isZsh) {
        $promptTemplateGetPSVersion.Remove('AnsiEffects')
        $promptTemplateGetPSVersion.Remove('ForegroundColor')
    }
    Add-PSPromptTemplateItem @promptTemplateGetPSVersion

    $itemCurrentPath = {
        param($ansi)
        $dirSep = [IO.Path]::DirectorySeparatorChar
        $regExDirSep = [Regex]::Escape($dirSep)
        $driveSep = if ( $env:OS -match 'Windows' ) { ':' } else {$null}
        If ( Get-Command git ) {
            $rootDir = git rev-parse --show-toplevel
            if ( $rootDir ) {
                $repoDir = (Split-Path $rootDir -Leaf) + $driveSep
                $regexRootDir = [regex]::Escape($rootDir)
            }
        }
        $currentPath = $PWD.Path -replace [regex]::Escape($HOME), '~' -replace $regExDirSep, '/' -replace $regexRootDir, $repoDir
        $driveRoot = $PWD.Drive.Name + $driveSep + "$dirSep"

        If ( $currentPath -match ".*$regExDirSep.*$regExDirSep.*$regExDirSep.*$regExDirSep.+" ) { # check if more than 4 directories
            $pwdAsDirArray = $currentPath.split($dirSep)
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
                $forceShowDir = "`e[91;103m" + 'prod' + $ansi
                If ( $thirdLast -ne 'prod' ) {
                    $forceShowDir = $forceShowDir + '\...'
                }
                $thirdLast = $forceShowDir
            }
            # The output trimmed current path.
            ($driveRoot + '...' + $dirSep + $thirdLast + $dirSep + $secondLast + $dirSep + $last) -replace '\\', '/'
        }
        Else {
            # If 4 directories or fewer, just output the path as normal.
            ( $currentPath) -replace '\\','/'
        }
    }

    $promptTemplateGetCurrentPath = @{
        Alignment = 'Left'
        ItemSeparator = ' '
        NoGroup = $true
        ForegroundColor = '40;169;120'
        ContentFunction = $itemCurrentPath
    }
    if ($isZsh) {$promptTemplateGetPSVersion.Remove('ForegroundColor')}
    Add-PSPromptTemplateItem @promptTemplateGetCurrentPath


    if ( Get-Command git ) {
        $getGitBranch = if ($isZsh) {
            {    
                param($ansi)
                $branchName = git branch --show-current
                If ( $? ) {
                    $out = $branchName
                    $parent = If ( $branchName -in 'main', 'master' ) {
                        $branchName
                    }
                    Else {
                        & {
                            if ( $branchName -match '^(develop|release)$') {
                                try {(git branch | Select-String '^\s*(main|master)$' | Sort-Object | Select-Object -First 1).Line.Trim()} catch {$branchName}
                            }
                            else {
                                try {
                                    (git branch | Select-String develop | Sort-Object | Select-Object -First 1).Line.Trim()
                                }
                                catch {
                                    (git branch | Select-String '^\s*(main|master)$' | Sort-Object | Select-Object -First 1).Line.Trim()
                                }
                            }
                        }
                    }
                }
                if ( $out ) {
                    $relativeCommits = (git rev-list --left-right --count origin/$parent...origin/$branchName ) -split '\s+'
                    $commitsBehind = if ( $relativeCommits[0] ) { "-$($relativeCommits[0])" }
                    $commitsAhead = if ( $relativeCommits[1] ) { "+$($relativeCommits[1])" }
                    $null = try {git log --oneline -n 50 --decorate=short | % { if ( $_ -match '^([a-zA-Z0-9]+) \((\S+)\)' ) { return } } } catch {}
                    $out += " $commitsBehind $commitsAhead "
                }
                return $out
            }
        } else {
            {
                param($ansi)
                $branchName = git branch --show-current
                If ( $? ) {
                    If ( $branchName -in 'main', 'master' ) {
                        $out = " `e[0m`e[93m " + $ansi + $branchName
                        $parent = $branchName
                    }
                    Else {
                        $out = " `e[0m`e[37m " + $ansi + $branchName
                        $parent = & {
                            if ( $branchName -match '^(develop|release)$') {
                                try {(git branch | Select-String '^\s*(main|master)$' | Sort-Object | Select-Object -First 1).Line.Trim()} catch {$branchName}
                            }
                            else {
                                try {
                                    (git branch | Select-String develop | Sort-Object | Select-Object -First 1).Line.Trim()
                                }
                                catch {
                                    (git branch | Select-String '^\s*(main|master)$' | Sort-Object | Select-Object -First 1).Line.Trim()
                                }
                            }
                        }
                    }
                }
                if ( $out ) {
                    $relativeCommits = (git rev-list --left-right --count origin/$parent...origin/$branchName ) -split '\s+'
                    $commitsBehind = if ( $relativeCommits[0] ) { "`e[91m-$($relativeCommits[0])" }
                    $commitsAhead = if ( $relativeCommits[1] ) { "`e[32m+$($relativeCommits[1])" }
                    $null = try {git log --oneline -n 50 --decorate=short | % { if ( $_ -match '^([a-zA-Z0-9]+) \((\S+)\)' ) { return } } } catch {}
                    $out += " $commitsBehind $commitsAhead `e[0m $ansi"
                }
                return $out
            }
        }

        $promptTemplateGetGitBranch = @{
            Alignment = 'Left'
            NoGroup = $true
            ForegroundColor = 'Orchid'
            ContentFunction = $getGitBranch
            AnsiEffects = 'italicize'
        }
        if ($isZsh) { $promptTemplateGetGitBranch.Remove('ForegroundColor') }

        Add-PSPromptTemplateItem @promptTemplateGetGitBranch
    }
}