using namespace System.Management.Automation

class FSRView {
    [string]$Path
    [string]$LineNo
    [string]$Line
    [Microsoft.PowerShell.Commands.MatchInfoContext]$Context
    [System.Text.RegularExpressions.Match[]]$Matches
    [string]$Filename
    [string]$PSPath
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
            Mandatory,
            ValueFromPipelineByPropertyName,
            ValueFromPipeline,
            Position=1
        )]
        [alias('PSPath', 'LP', 'Path')]
        [string]$InputObject = '.',
        
        [Parameter(Mandatory, ParameterSetName = 'RegExPattern', Position=0)]
        [Parameter(Mandatory, ParameterSetName = 'SimplePattern', Position=0)]
        [string]$Pattern,

        [Parameter(Mandatory, ParameterSetName = 'RegExNotMatch')]
        [Parameter(Mandatory, ParameterSetName = 'SimpleNotMatch')]
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
                $err = [ErrorRecord]::new("$_ is not a valid Encoding given by [System.Text.Encoding]::GetEncodings() or a static property of [System.Text.Encoding]", $null, 'InvalidArgument', $null)
                $PSCmdlet.ThrowTerminatingError($err)
            }
        })]
        [string]$Encoding,

        [switch]$List,
        [switch]$Quiet,
        [switch]$NoEmphasis,

        # Activate to include binary files.
        [switch]$IncludeBinaryFiles
    )
    begin {
        $Pattern  = $Pattern -Replace '^([*])$','.$1' # replaces wildcard * to a regex .*, as only regex is allowed.

        # region build [IO.Directory]::GetFiles() and Get-ChildItem params. Get-ChildItem is a fallback if GetFiles() fails.
        $GCIparams = @{'File' = $true}
        $enumerationOptions = [System.IO.EnumerationOptions]::new()
        $AttributesToSkip = @('ReparsePoint')
        If ( !($NoRecurse) ) {
            $enumerationOptions.RecurseSubdirectories = $true
        } else {
            $AttributesToSkip += 'Directory'
        }
        If ( $FilterFile ) {
            $GCIparams.Add( 'Filter' , $FilterFile)
        }
        $binaryFilter = If ( !$IncludeBinaryFiles ) {  
            $AttributesToSkip += 'Compressed'
            '(?<![.]zip|7z|.ar|dll|class|t?gz|exe|iso|a?vhd|sha1|checksum|vm.{0,2}|png|jpe?g|svg|tiff|gif|bmp|lz4|snappy|zstd)$'
        }
        
        $binaryFilterPattern = [regex]::new($binaryFilter, ('Compiled', 'IgnoreCase'))
        
        $enumerationOptions.AttributesToSkip = $AttributesToSkip
        # end region

        # region build Select-String params
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
        # end region 

        $ansi = [char]27
        $ansiOrange  = "$ansi[38;5;202m"
        $ansiYellow  = "$ansi[93m"
        $ansiReset   = "$ansi[0m"
        $ansiReverse = "$ansi[7m"
        $ansiReverseOff = "$ansi[27m"
        $ansiStrikeOff  = "$ansi[29m"
        $ansiStrike     = "$ansi[9m"

    }
    process {
        $SLSInput = [Collections.Generic.List[string]]@()

        # Process path if it was input as only a * or .
        $path = & {
            If ( $InputObject -in '*','.' ) {
                $PWD
            }
            Else {
                $InputObject
            }
        }
        # get full paths of all files to be searched
        If ( Test-Path $path ) {
            $isFilePath = $true
            Foreach ( $fullPath in Convert-Path $path ) {
                try {
                    [string[]]$subFolderfileList = [System.IO.Directory]::GetFiles( $fullPath, $FilterFile, $enumerationOptions )
                }
                catch {
                    [string[]]$subFolderfileList = (Get-ChildItem -LiteralPath $fullPath @GCIParams -Recurse:(!$NoRecurse) -Force:$Force -Attributes !ReparsePoint).FullName
                }
                try {
                    if ( $binaryFilter ) {
                        $SLSInput.AddRange( [string[]]($subFolderfileList | Where { $_ -and $binaryFilterPattern.Match($_).Success }) )
                    } else {
                        $SLSInput.AddRange( [string[]]$subFolderfileList )
                    }
                } catch [ArgumentNullException] {}
            }
            $subFolderfileList = $null
        }
        # If not searching for a file, then prepare to Select-String on raw text.
        Else {
            $SLSParams.InputObject = $path
            $SLSInput.Add($path)
        }
        # Run Select-String
        Foreach ( $item in $SLSInput ) {
            # Last param building for Select-String and output as a relative filepath.
            If ( $isFilePath ) {
                $SLSParams.LiteralPath = $item
                $filePath = Resolve-Path -LiteralPath $item -Relative
            }

            Select-String @SLSparams | ForEach-Object { If ( $Quiet ) { $_ } Else {
                If ( $Context ) {
                    # Get the right lines to display in the output when Select-String's -Context parameter is used.
                    # By default, the preceding and succeeding lines are output with an offset, especially if
                    # the span of context lines overlaps with another match. Both the offset and overlap are handled here.
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
                        # handle empty context attributes, such as if the parameter isn't selected.
                        if ( !($displayPreContext = $_.Context.DisplayPreContext | Out-String) ) { $displayPreContext = '' }
                        if ( !($displayPostContext = $_.Context.DisplayPostContext | Out-String) ) { $displayPostContext = '' }
                        
                        # Implement emphasis highlighting here.
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
                        # The output for file input
                        [FSRView]@{
                            Path = $ansiOrange + $filePath + ":$ansiReset"
                            LineNo  = $preLineNumber + $ansiYellow + $_.LineNumber + "$ansiReset" + $postLineNumber
                            Line = '{0}{1}{2}{3}' -f $displayPreContext,
                                $emphasizedLine,
                                [Environment]::NewLine,
                                $displayPostContext -replace "$([Environment]::NewLine)$"
                            Context = $_.Context
                            Matches = $_.Matches
                            Filename = Split-Path $filepath -Leaf
                            PSPath = $filePath
                        }
                    }
                    # The output for raw string input
                    else {
                        [FSRView]@{
                            Line = $_.ToEmphasizedString($_.Line)
                            Context = $_.Context
                            Matches = $_.Matches
                        }
                    }
                }
            }}
        }
    }
}