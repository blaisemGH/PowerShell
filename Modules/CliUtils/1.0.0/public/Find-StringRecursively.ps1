class ViewGrep {
    [string]$Path
    [string]$Num
    [string]$Line
    hidden [Microsoft.PowerShell.Commands.MatchInfoContext]$Context
    hidden [System.Text.RegularExpressions.Match[]]$Matches
    hidden [string]$Filename
}
<#
    .DESCRIPTION
        This is a wrapper function that combines Get-ChildItem and Select-String into a single function.
        It is intended to emulate the grep command in Unix and is also aliased to grep.
        
        Ultimately after a lot of wrangling with this function, the niche I found for it was in output
        formatting and convience. It is prettier than Select-String and more reponsive to type than
        gci | sls, which feels somehow disruptive to type out after being used to typing a quick grep
        in unix.

    .NOTES
        Hint: Pipe this function into Format-Table -Wrap to avoid truncated output.
        As mentioned above, this function is intended to emulate grep, so the parameters Path and Pattern
        are switched in position like Unix grep (`grep <pattern> <path>`).

#>
Function Find-StringRecursively {
    [CmdletBinding(DefaultParameterSetName='RegExPattern')]
    Param (
        [Parameter(
            Mandatory=$true,
            ValueFromPipelineByPropertyName=$true,
            ValueFromPipeline,
            Position=1
        )]
        [alias('PSPath')]
        [string]$Path = '.',

        [Parameter(Mandatory=$true, ParameterSetName = 'RegExPattern', Position=0)]
        [Parameter(Mandatory=$true, ParameterSetName = 'SimplePattern', Position=0)]
        [string]$Pattern,

        [Parameter(Mandatory=$true, ParameterSetName = 'RegExNotMatch')]
        [Parameter(Mandatory=$true, ParameterSetName = 'SimpleNotMatch')]
        [string]$NotMatch,

        [Parameter(ParameterSetName = 'RegExPattern')]
        [Parameter(ParameterSetName = 'RegExNotMatch')]
        [switch]$AllMatches,

        [Parameter(ParameterSetName = 'SimplePattern')]
        [Parameter(ParameterSetName = 'SimpleNotMatch')]
        [switch]$SimpleMatch,

        [string]$FilterFile = '*',

        [alias('nr')]
        [switch]$NoRecurse,
        [switch]$Force,
        [switch]$CaseSensitive,
        [int[]]$Context,

        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            (
                [Text.Encoding]::GetEncodings().Name + ([Text.Encoding] | Get-Member -Type Property -Static | Select-Object -exp Name)
            ) |    Where-Object {
                $_ -like "$wordToComplete*"
            }
        })]
        [ValidateScript({
            If ($_ -in [Text.Encoding]::GetEncodings().Name -or 
                $_ -in ([Text.Encoding] | Get-Member -Type Property -Static | Select-Object -exp Name)
            ) {
                $true
            }
            Else {
                Throw "$_ is not a valid Encoding given by [System.Text.Encoding]::GetEncodings() or a static property of [System.Text.Encoding]"
            }
        })]
        [string]$Encoding,

        [switch]$List,
        [switch]$Quiet,
        [switch]$NoEmphasis,

        # Activate to include binary files.
        [switch]$IncludeBinaryFiles,

        # Sets the maximum width for the path column in the output, assuming a file was searched. 0 = unlimited width and absolute path.
        [ValidateRange(1)]
        [int]$MaxFileNameWidth
    )
    begin {
        $odir = Convert-Path (PWD)
        $Pattern  = $Pattern -Replace '^([*+}])$','.$1' #((?>^|[^.)}[\]]))([*+?])','$1.$2'

        $GCIparams = @{'File' = $true}
        $recurse = & {
            If ( !($NoRecurse) ) {
                'AllDirectories'
            }
            Else {
                'TopDirectoryOnly'
            }
        }
        If ( $FilterFile ) {
            $GCIparams.Add( 'Filter' , $FilterFile)
        }
        $binaryFilter = If ( $IncludeBinaryFiles ) { '^.' } Else { '(?<![.]zip|7z|.ar|dll|class|t?gz|exe|iso|a?vhd|sha1|checksum|vm.{0,2}|png|jpe?g|svg|tiff|gif|bmp|lz4|snappy|zstd)$' }
        $binaryFilterPattern = [regex]::new($binaryFilter, ('Compiled', 'IgnoreCase'))

        $SLSparams = @{}
        If ( $Pattern ) {
            $SLSparams.Add( 'Pattern'        , $Pattern)
        }
        If ( $NotMatch ) {
            $SLSparams.Add( 'NotMatch'        , $NotMatch)
        }
        If ( $AllMatches ) {
            $SLSparams.Add( 'AllMatches'    , $true)
        }
        If ( $SimpleMatch ) {
            $SLSparams.Add( 'SimpleMatch'    , $SimpleMatch)
        }
        If ( $CaseSensitive ) {
            $SLSparams.Add( 'CaseSensitive' , $CaseSensitive)
        }
        If ( $Context ) {
            $SLSparams.Add( 'Context' , $Context)
            #$contextPointer    = "$ansi[38;5;202m>:$ansi[0m"
            $preContextSkip        = [Environment]::NewLine * $Context[0]
        }
        If ( $Encoding ) {
            $SLSparams.Add( 'Encoding'    , $Encoding)
        }
        If ( $List ) {
            $SLSparams.Add( 'List'    , $true)
        }
        If ( $Quiet ) {
            $SLSparams.Add( 'Quiet'    , $true)
        }
        $unlimitedWidth = $false
        If ( $PSBoundParameters.ContainsKey('MaxFileNameWidth') -and $MaxFileNameWidth -eq 0 ) {
            $unlimitedWidth = $true
        }
        
        $ansi = [char]27
        $ansiOrange  = "$ansi[38;5;202m"
        $ansiYellow  = "$ansi[93m"
        $ansiReset   = "$ansi[0m"
        $ansiReverse = "$ansi[7m"
        $ansiReverseOff = "$ansi[27m"
        $ansiStrikeOff  = "$ansi[29m"
        $ansiStrike     = "$ansi[9m"
        
        $fakePath    = "   "
        $fmtFakePath = "$ansiReverse$ansiStrike$fakePath$ansiReverseOff$AnsiStrikeOff"

		$notPath   = $false
    }
    process {
        $SLSInput = [Collections.Generic.List[string]]@()
        $path = & {
            If ( $Path -in '*','.' ) {
                $odir
            }
            Else {
                $Path
            }
        }
        $rdir = Convert-Path ($Path)
        If ( Test-Path $path ) {
            $isFilePath = $true
            Foreach ( $fullPath in Convert-Path $path ) {
                try {
                    [string[]]$subFolderfileList = [System.IO.Directory]::GetFiles( $fullPath, $FilterFile, $recurse )
                }
                catch {
                    [string[]]$subFolderfileList = ( Get-ChildItem -LiteralPath $fullPath @GCIParams -Recurse:(!$NoRecurse) -Force:$Force | Where Mode -notmatch '^l').FullName
                }
                try {
                    $SLSInput.AddRange( [string[]]($subFolderfileList | Where { $_ -and $binaryFilterPattern.Match($_).Success }) )
                } catch [ArgumentNullException] {}
            }
            $maxFileLength = [Math]::Min(100, ($subFolderfileList | Measure-Object -Property length -Maximum).Maximum)
            $subFolderfileList = $null
        }
        Else {
            $SLSParams.InputObject = $Path
            $SLSInput.Add($Path)
        }
        try { cd $rdir # move to root dir because Resolve-Path -Relative below is ugly when you input grep ../../../ etc.
        Foreach ( $item in $SLSInput ) {
            If ( $isFilePath ) {
                $SLSParams.LiteralPath = $item
                $filepath = Resolve-Path $item -Relative
                <#
                    Goal of $trimmedFilePath is to restrict the filepath to $limitPath characters or less,
                    with these conditions for filepaths -gt $limitPath characters:
                        * retain the root folder (testing felt weird without it)
                        * retain as much as possible from the leaf folder
                        * if root.length + leaf.length -gt $limitPath, then take near 0.5x $limitPath from
                          the left of the string, and near 0.5x $limitPath from the right.
                          ("near" = subtracting $fakePath.Length, i.e., $limitPath - 2x $fakePath.Length)
                    Note that $limitPath is set by the input argument $MaxFileNameWidth, or if unset then 
                    via $maxFileLength = min(70, the longest relative filepath in the search path)
                #>
                $limitPath = & {
                    if ( $MaxFileNameWidth ) { $MaxFileNameWidth }
                    elseif ( $unlimitedWidth ) {0}
                    else { $maxFileLength }
                }
                $trimmedFilePath = & {
                    if ( $unlimitedWidth ) {
                        Convert-Path $item
                    }
                    elseif ( $filepath.Length -gt $limitPath ) {
                        $pathSplit = $filepath.split( [IO.Path]::DirectorySeparatorChar )
                        $pathSplitCount = $pathSplit.Count
                        # Check if directories in between root and leaf (count -gt 2) and prepare to trim them.
                            if ($pathSplitCount -gt 2) {
                                $leaf = $pathSplit[-1]
                                $count = 1
                                # Derive root as all leading folders in filepath with . or .. followed by
                                # the first folder that has real characters. This ensures a meaningful root
                                # in case the first folder is just a .. relative path.
                                    $rootSplit = Foreach ( $folder in $pathSplit ) {
                                        # If root overruns into leaf, then break, as we already have leaf in $leaf.
                                        if ( $count -eq ($pathSplitCount - 1) ) { $folder; break }
                                        # If root has a . or .., then include it.
                                        elseif ($folder -match '^[.]{1,2}$') {
                                            $folder
                                            $count += 1
                                        }
                                        # If root is not a ., .., or our leaf, then capture it and break.
                                        else { $folder; break }
                                    }
                                    $root = $rootSplit -join [IO.Path]::DirectorySeparatorChar
                                # If there is an intermediary folder and it isn't part of root, then parse it.
                                    if (
                                        ($rootSplit.Count + 1) -lt $pathSplitCount -and
                                        (   # Also need to check if we have room—$root and $leaf -lt $limitPath
                                            $root.Length + $leaf.Length + $fakePath.Length + 2
                                        ) -lt $limitPath
                                    ) {
                                        # Taking all the intermediary folders between the root and leaf,
                                        # then join them into a single string.
                                        $middle = $pathSplit[($rootSplit.Count)..($pathSplitCount - 2)] -join [IO.Path]::DirectorySeparatorChar
                                        <#
                                        We still haven't trimmed anything yet. The joined string between root
                                        and leaf needs to be trimmed. This middle portion will be prepended
                                        and appended with a directory separator, so we subtract 2 for those 
                                        characters, plus we subtract the $fakePath, and then also the length
                                        of root and leaf. The remaining number is how many characters to include
                                        from the end of the middle string to meet $limitPath.
                                        #>
                                            $trimMiddle = $fmtFakePath + $middle.Substring( $middle.Length - ($limitPath - $fakePath.Length - $root.Length - $leaf.Length - 2))
                                        # Output the root, trimmed middle, and leaf files.
                                        Join-Path $root $trimMiddle $leaf
                                    }
                                # If there was no middle directory, but the filepath had more than 2 folders,
                                # then it's a super weird path with either a huge root or huge leaf or both.
                                # Take half $limitPath on the left and half on the right. Middle is $fakePath.
                                    else {
                                        $keepHalf = [Math]::Floor( ($limitPath + $fakePath.Length) / 2)
                                        $filepath.Substring(0,$keepHalf) + $fmtFakePath + $filepath.Substring(
                                            ($filepath.Length - ($limitPath - $keepHalf))
                                        )
                                    }
                            }
                            else {
                                # The filepath has the structure folder/leaf, and it's over $limitPath characters.
                                # Take half $limitPath from the left and half from the right.
                                # Everything else in the middle becomes $fakePath.
                                $keepHalf = [Math]::Floor( ($limitPath + $fakePath.Length) / 2)
                                $filepath.Substring(0,$keepHalf) + $fmtFakePath + $filepath.Substring(
                                    ($filepath.Length - ($limitPath - $keepHalf))
                                )
                            }
                    }
                    # If the filepath is not > $limitPath characters, no trimming needed.
                    Else { $filepath }
                    # Did I really just need 80 lines to account for super long/weird filepaths? :(
                    # There must be a better way, but I can't stand spending more time on this right now.
                }
            }
            Select-String @SLSparams | ForEach-Object { If ( $Quiet ) { $_ } Else {
                If ( $Context ) {
                    $preCount = try {@($_.Context.DisplayPreContext.split([Environment]::NewLine)).Count } catch { $_.Context.DisplayPostContext.Count }
                    $preLineNumber = ''
                    $postCount = try {@($_.Context.DisplayPostContext.split([Environment]::NewLine)).Count } catch { $_.Context.DisplayPostContext.Count }
                    $postLineNumber = ''
                    If ( $preCount ) {
                        ForEach ($LineNumber in $preCount..1) {
                            $preLineNumber += ($_.LineNumber - $LineNumber).ToString() + [Environment]::NewLine
                        }
                    }
                    If ( $postCount ) {
                        ForEach ($LineNumber in 1..$postCount) {
                            $postLineNumber += [Environment]::NewLine + ($_.LineNumber + $LineNumber).ToString()
                        }
                    }
                }
                & {
                    If ( $isFilePath ) {
                        if ( !($displayPreContext = $_.Context.DisplayPreContext | Out-String) ) { $displayPreContext = '' }
                        if ( !($displayPostContext = $_.Context.DisplayPostContext | Out-String) ) { $displayPostContext = '' }
                        $emphasizedLine = & {
                            if ($NoEmphasis) {
                                $_.Line
                            }
                            # For Select-String outputs with -Context, which are multiline with the form
                            # .*><filename>:<line number>:<preContext><line><postContext>
                            # This regex captures all of that and keeps only <line>.
                            elseif ($_.ToEmphasizedString($_.line) -match 
                                '(?s).*(?-s)> .*:[0-9]+:(?<line>.+)\n?(?s).*'
                            ) {
                                $Matches.line
                            }
                            # Filter Select-String's output of <filename>:<linenumber>:<line> to just <line>
                            else {
                                $_.ToEmphasizedString($_.line) -replace ('>? ?' + ([regex]::Escape($_.Path + ':' + $_.LineNumber))  + ':')
                            }
                        }
                        [ViewGrep]@{
                            Path = "{0,-$limitPath}" -f ($ansiOrange + $trimmedFilePath + ":$ansiReset")
                            Num  = '{0,-9}' -f ( $preLineNumber + $ansiYellow + $_.LineNumber + "$ansiReset" + $postLineNumber )
                            Line = '{0}{1}{2}{3}' -f $displayPreContext,
                                $emphasizedLine,
                                [Environment]::NewLine,
                                $displayPostContext -replace "$([Environment]::NewLine)$"
                            Context = $_.Context
                            Matches = $_.Matches
                            Filename = $filepath
                        }
                    }
                    else {
                        [ViewGrep]@{
                            Line = $_.ToEmphasizedString($_.Line)
                            Context = $_.Context
                            Matches = $_.Matches
                        }
                    }
                }
            }}
        }}
        finally { cd $odir }
    }
}