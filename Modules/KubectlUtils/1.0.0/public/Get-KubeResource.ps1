Function Get-KubeResource {
	[CmdletBinding()]
	Param(
		[Parameter(Mandatory, Position = 0)]
		[string]$ResourceName,

		[Parameter(Position = 1)]
		[Alias('i')]
        [ArgumentCompleter({
            param($cmdName, $paramName, $wordToComplete, $cmdAst, $fakeBoundParameters)
            if ( $fakeBoundParameters.ResourceName ) {
                return (
                    kubectl get $fakeBoundParameters.ResourceName -o name | ForEach { $_ -split '/' | Select-Object -Last 1 } | Where {$_ -like "$wordToComplete*"}
                )
            }
        })]
		[string]$ItemName,

		[Parameter(Position = 2)]
		[Alias('o')]
		[ValidateSet('wide','json','yaml','name')]
		[string]$OutputType = 'json',
		
		[string]$Namespace = [Kube]::Checkpoint_CurrentNamespace()
	)
	$getName = Switch ($ResourceName) {
		{ $_ -in 'p','pod'	} { 'pods'			}
		{ $_ -in 'd'		} { 'deploy'		}
		{ $_ -in 's'		} { 'services'		}
		{ $_ -in 'st'		} { 'statefulsets'	}
		{ $_ -in 'j'		} { 'jobs'			}
		{ $_ -in 'i'		} { 'ingress'		}
		DEFAULT { $_ }
	}
	
	$cmd = [Text.StringBuilder]::new()
	[void]$cmd.AppendLine("kubectl -n $Namespace get $getName")
	if ($itemName) {
		[void]$cmd.AppendLine($itemName)
	}
	if ( $outputType -eq 'json' ) {
		[void]$cmd.AppendLine('-o json | ConvertFrom-Json')
	}
	ElseIf ( $outputType -eq 'yaml' ) {
		[void]$cmd.AppendLine('-o yaml')
	}
	ElseIf ( $outputType -match '^name' ) {
		[void]$cmd.AppendLine('-o name')
	}
	ElseIf ($outputType) {
		[void]$cmd.AppendLine("-o $outputType | ForEach { `$_ -replace ' {2,}', '#' } | ConvertFrom-Csv -Delimiter '#'")
	}
	Else {
		[void]$cmd.AppendLine("| ForEach { `$_ -replace ' {2,}', '#' } | ConvertFrom-Csv -Delimiter '#'")
	}

	$o = $out = Invoke-Expression ( $cmd.ToString() -replace [Environment]::NewLine, ' ' )

	If ($out | Get-Member -Membertype NoteProperty -Name items) {
		$o = $out.items
	}

	If ( $PSBoundParameters.OutVariable ) {
		Return $o
		Write-Host ($o | Format-Table)
	}
	Else {
		$script:k = $o
		$o | Format-Table -AutoSize -Wrap
	}
}