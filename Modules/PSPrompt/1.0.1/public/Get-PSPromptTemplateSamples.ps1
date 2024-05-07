function Get-PSPromptTemplates {
    $getLatestInvocationDuration = {
        $duration = $d = (Get-History)[-1].Duration
        switch ($duration) {
            {$_.Days} { '{0}d {1}h{2}m{3}.{4}s' -f $d.Days, $d.Hours, $d.Minutes, $d.Seconds, $d.Milliseconds; break }
            {$_.Hours} { '{0}h{1}m{2}.{3}s' -f $d.Hours, $d.Minutes, $d.Seconds, $d.Milliseconds; break }
            {$_.Minutes} {'{0}m{1}.{2}s' -f $d.Minutes, $d.Seconds, $d.Milliseconds; break }
            {$_.Seconds} {'{0}.{1}s' -f $d.Seconds, $d.Milliseconds }
            DEFAULT { '{0}ms' -f $d.Milliseconds }
        }
    }
    $getPowerShellVersion = { $PSVersionTable.PSVersion.ToString() }
    $getCurrentTimestamp = { (Get-Date).ToString('HH:mm:ss') }
    $getCurrentDirectory = { ('📂 ' + (Get-Location).Path)  }
    $getCurrentDirectoryStylized = {
        param($ansi)
        $dirSep = [IO.Path]::DirectorySeparatorChar
        $regExDirSep = [Regex]::Escape($dirSep)
        If ( $PWD -match ".*$regExDirSep.*$regExDirSep.*$regExDirSep.*$regExDirSep.+" ) { # check if more than 4 directories
            $pwdAsDirArray = (Get-Location).ToString().split($dirSep)
            $thirdLast = $pwdAsDirArray[-3]
            $secondLast = $pwdAsDirArray[-2]
            $last = $pwdAsDirArray[-1]
                # caps the length of each folder
            if ($thirdLast.length	-gt 12	) { $thirdLast	= $thirdLast.SubString(0,12) }
            if ($secondLast.length	-gt 12	) { $secondLast	= $secondLast.SubString(0,12) }
            if ($last.length	-gt 15	) { $last	= $last.SubString($last.length - 16,16) }
        
                # checks for the string prod and highlights it.
                # I use this as a reminder when I am in a prod repo, so I am more careful about editing prod code.
            If ( $pwdAsDirArray -Contains 'prod' ) {
                $forceShowDir = "`e[91m" + 'prod' + $ansi
                If ( $thirdLast -ne 'prod' ) {
                    $forceShowDir = $forceShowDir + '\🦆'
                }
                $thirdLast = $forceShowDir
            }
            # The output trimmed current path.
            ('📂 ' + $PWD.Drive.Root + '🦆' + $dirSep + $thirdLast + $dirSep + $secondLast + $dirSep + $last) -replace '\\','/'
        }
        Else {
            # If 4 directories or fewer, just output the path as normal.
            ('📂 ' + (Get-Location).Path) -replace '\\','/'
        }
    }

    $getGitBranch = { return git branch --show-current }
    $getGitBranchStylized = {
        param($ansi)
        $branchName = git branch --show-current
        If ( $? ) {
            If ( $branchName -in 'main', 'master' ) {
                " `e[93m " + $ansi + $branchName.ToUpper()
            }
            Else {
                " `e[37m " + $ansi + $branchName 
            }
        }
    }
   
    Write-Host 'This function returns sample templates for your prompt line.
    As a quick tutorial, start by saving them to a variable:
        $samples = Get-PSPromptTemplateSamples
        $samples | Format-Table -Wrap
    
    To add a timer of your last command''s duration, use the latestInvocationDuration key.
    Add it via a function:
        Add-PSPromptTemplateItem -Content $samples.latestInvocationDuration 
    
    or via dictionary splatting:
        $template = @{
            ContentFunction = $samples.latestInvocationDuration
        }
        Add-PSPromptTemplateItem @template
    
    You can add colors by setting BackgroundColor or ForegroundColor in the $template config. For color ideas, try:
        Get-FormattedKnownColors | ft -Autosize
    
    These colors can be entered explicitly into the template, e.g., BackgroundColor = ''DeepPink''.
    Using the above 2 examples:
        Add-PSPromptTemplateItem -Content $samples.latestInvocationDuration -BackgroundColor DeepPink
        or
        $template = @{
            BackgroundColor = ''DeepPink''
            ContentFunction = $samples.latestInvocationDuration
        }
        Add-PSPromptTemplateItem @template
    Explicit string values as semicolon-delimited r;g;b or #hexademical are also accepted.

    For more information, enter
        help about_PSPrompt # General info on the module
        help Add-PSPromptTemplateItem # See parameters for a list of valid attributes to specify.
    '

    return @{
        latestInvocationDuration = $getLatestInvocationDuration
        powershellVersion = $getPowerShellVersion
        currentTimestamp = $getCurrentTimestamp
        currentDirectory = $getCurrentDirectory
        currentDirectoryStylized = $getCurrentDirectoryStylized
        gitBranch = $getGitBranch
        gitBranchStylized = $getGitBranchStylized        
    }
}