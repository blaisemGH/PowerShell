Function Find-StringRecursively {
    [CmdletBinding(DefaultParameterSetName='RegExPattern')]
    Param (
        [Parameter(
            Mandatory=$true,
            ValueFromPipelineByPropertyName=$true,
            Position=1
	)]
        [alias('Path')]
        [string]
            $FullName = '.',
        [Parameter(Mandatory=$true, ParameterSetName = 'RegExPattern' , Position=0)]
        [Parameter(Mandatory=$true, ParameterSetName = 'SimplePattern', Position=0)]
        [string]
            $Pattern,
        [Parameter(Mandatory=$true, ParameterSetName = 'RegExNotMatch' )]
        [Parameter(Mandatory=$true, ParameterSetName = 'SimpleNotMatch')]
        [string]
            $NotMatch,
        [Parameter(ParameterSetName = 'RegExPattern'  )]
        [Parameter(ParameterSetName = 'RegExNotMatch' )]
        [switch]
            $AllMatches,
        [Parameter(ParameterSetName = 'SimplePattern' )]
        [Parameter(ParameterSetName = 'SimpleNotMatch')]
        [switch]
            $SimpleMatch,
        [string]
            $FilterFile = '*',
        [alias('nr')]
        [switch]
            $NoRecurse,
        [switch]
            $Force,
        [switch]
            $CaseSensitive,
        [int[]]
            $Context,
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
        [string]
            $Encoding,
        [switch]
            $List,
        [switch]
            $Quiet
    )
    begin {
        $ansi = [char]27
        $odir = Convert-Path (PWD)
        $Pattern  = $Pattern -Replace '^([*+}])$' , '.$1' #((?>^|[^.)}[\]]))([*+?])' , '$1.$2'

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

        $contextPointer = $null
        $SLSparams = @{}
        $SLSparams.Add(     'LiteralPath'   , $Null)
        If ( $Pattern ) {
            $SLSparams.Add( 'Pattern'       , $Pattern)
        }
        If ( $NotMatch ) {
            $SLSparams.Add( 'NotMatch'      , $NotMatch)
        }
        If ( $AllMatches ) {
            $SLSparams.Add( 'AllMatches'    , $true)
        }
        If ( $SimpleMatch ) {
            $SLSparams.Add( 'SimpleMatch'   , $SimpleMatch)
        }
        If ( $CaseSensitive ) {
            $SLSparams.Add( 'CaseSensitive' , $CaseSensitive)
        }
        If ( $Context ) {
            $SLSparams.Add( 'Context'   , $Context)
			#$contextPointer = "$ansi[38;5;202m>:$ansi[0m"
        }
        If ( $Encoding ) {
            $SLSparams.Add( 'Encoding'  , $Encoding)
        }
        If ( $List ) {
            $SLSparams.Add( 'List'  , $true)
        }
        If ( $Quiet ) {
            $SLSparams.Add( 'Quiet' , $true)
        }
    }
    process {
        $fileList = [Collections.Generic.List[string]]@()
        $path = If ( $fullName -in '*' , '.' ) {
            $odir
        }
        Else {
            $fullName
        }
        Foreach ( $fullPath in (Convert-Path $path) ) {
            $cleanPath = $fullPath
            try {
                [string[]]$subFolderfileList = [System.IO.Directory]::GetFiles( $cleanPath, $FilterFile, $recurse )
            }
            catch {
                [string[]]$subFolderfileList = ( Get-ChildItem $cleanPath @GCIParams -Recurse:(!$NoRecurse) -Force:$Force ).FullName
            }
            $fileList.AddRange($subFolderfileList)
        }
        $maxFileLength = [Math]::Min(90, ($fileList | Measure-Object length -Maximum | Select-Object -ExpandProperty Maximum))

        Foreach ( $file in $fileList ) {
            $SLSParams.LiteralPath = $file
            Select-String @SLSparams | ForEach-Object {
                $filePath = $_.path.replace($odir , '.')
                if ( $Context) {
                    $preCount = @($_.Context.PreContext.split([Environment]::NewLine)).Count
                    $preLineNumber = ''
                    $postCount = @($_.Context.PostContext.split([Environment]::NewLine)).Count
                    $postLineNumber = ''
                    If ( $preCount ) {
                        ForEach ($LineNumber in $preCount..1 ) {
                            $preLineNumber  += ($_.LineNumber - $LineNumber).ToString() + [Environment]::NewLine
                        }
                    }
                    If ( $postCount ) {
                        ForEach ($LineNumber in 1..$postCount) {
                            $postLineNumber += [Environment]::NewLine + ($_.LineNumber + $LineNumber).ToString()
                        }
                    }
                }

                [PSCustomObject]@{
                    Filename  = "{0 , -$maxFileLength}" -f ("$ansi[38;5;202m"  +  ($filePath.substring([math]::max($filePath.Length - 80, 0)))   +  ":$ansi[0m")
                    Line      = '{0 , -9}' -f ( $preLineNumber + "$ansi[93m" + $_.LineNumber  +  ">$ansi[0m" + $postLineNumber )
                    Contents  = '{0}{1}{2}' -f ($_.Context.PreContext | Out-String), ($contextPointer + $_.Line), ($_.Context.PostContext | Out-String) -replace "$([Environment]::NewLine)$" #'{0, -155}' -f $_.Line
                } | Format-Table -HideTableHeaders -Wrap
            }
        }
    }
}
