Function Copy-KubeFile {
	[CmdletBinding(DefaultParameterSetName='inferDirection')]
	Param(
		[Parameter(Mandatory, Position=0)]
		[alias('pod')]
		[string]$PodName,
		[Parameter(Mandatory, Position=1)]
		[ArgumentCompleter(
			{
				param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
				$pod = $fakeBoundParameters.PodName
				$lsCmd = "ls -dlA $wordToComplete*"
				[string[]]@(kubectl exec $pod -- sh -c $lsCmd) |
					ForEach {
                        if ( $_ -match '^l' ) {
                            ($_ -split ' ')[-3]
                        }
                        elseif ( $_ -match '^d' ) {
                            ($_ -split ' ')[-1] + '/'
                        }
                        Else {
                            ($_ -split ' ')[-1]
                        }
                    } |
                    Where-Object {
                        $_ -like "$wordToComplete*"
                    }
			}
		)]
		[alias('r')]
		[string]$RemotePath,
		[Parameter(Mandatory, Position=2)]
		[alias('l')]
		[string]$LocalPath='.',
		[Parameter(Position=3)]
		[int]$retries,
		[Parameter(Mandatory,ParameterSetName='download')]
		[Alias('d')]
		[switch]$Download,
		[Parameter(Mandatory,ParameterSetName='upload')]
		[alias('u')]
		[switch]$Upload
	)
	$PodPath = "${PodName}:$RemotePath"
	If ( $PSCmdlet.ParameterSetName -eq 'inferDirection' ) {
		$direction = & {
			If ( !(Test-Path $LocalPath -PathType Leaf) ) {
				'download'
			}
			ElseIf ( $RemotePath -match '(?<![\\])/$' ) {
				'upload'
			}
			Else {
				Test-ReadHost 'cp which direction?[download|upload]' -ValidationStrings 'download','d','upload','u'
				Write-Host 'Next time, preempt this question by adding the argument -d or -u for download or upload respectively, or imply the direction by either ending the RemotePath with a / (upload) or setting the LocalPath to a directory, a non-existent file, or a "." (download).'
			}
		}
	}
	If ( ($resolvedLocalPath = $LocalPath) -eq '.' ) {
		$resolvedLocalPath = Split-Path $RemotePath -Leaf
	}
	If ( $Upload -or $direction -in 'upload', 'u') {
		kubectl cp $LocalPath $PodPath --retries $retries
	}
	If ( $Download -or $direction -in 'download', 'd') {
		kubectl cp $PodPath $resolvedLocalPath --retries $retries
	}
}