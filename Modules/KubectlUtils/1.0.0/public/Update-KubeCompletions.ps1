Function Update-KubeCompletions {
	$sbGetPodNames = {
		param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

		[Kube]::Pods() | Where-Object {
			$_ -like "$wordToComplete*"
		}
	}.GetNewClosure()

	$sbGetNamespaces = {
		param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
		
		[Kube]::Namespaces() | Where-Object {
			$_ -like "$wordToComplete*"
		}
	}.GetNewClosure()

	$sbGetResource = {
		param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
		[Kube]::ArrayOfApiResources | 
				Where-Object {
					$_ -like "$WordToComplete*"
				}
	}
	$sbGetItem = {
		param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
		
		$resourceName = Switch ($fakeBoundParameters.ResourceName) {
			{ $_ -in 'p','pod'	} { 'pods'			}
			{ $_ -in 'd'		} { 'deploy'		}
			{ $_ -in 's'		} { 'services'		}
			{ $_ -in 'st'		} { 'statefulsets'	}
			{ $_ -in 'j'		} { 'jobs'			}
			{ $_ -in 'i'		} { 'ingress'		}
			DEFAULT { $_ }
		}
		If ( $fakeBoundParameters.Namespace ) {
			[DynamicKube]::CurrentNamespace = $fakeBoundParameters.Namespace
		}
		ElseIf ( [Kube]::CurrentNamespace ) {
			[DynamicKube]::CurrentNamespace = [Kube]::CurrentNamespace
		}
		Else {
			[DynamicKube]::CurrentNamespace = [Kube]::Checkpoint_CurrentNamespace()
		}
		[DynamicKube]::"Get_$resourceName"() |
				Where-Object {
					$_ -like "$WordToComplete*"
				}
	}
	Register-ArgumentCompleter -CommandName Enter-KubePod -Parameter PodName -ScriptBlock $sbGetPodNames
	Register-ArgumentCompleter -CommandName Copy-KubeFile -Parameter PodName -ScriptBlock $sbGetPodNames
	Register-ArgumentCompleter -CommandName Set-KubeNamespace -Parameter Namespace -ScriptBlock $sbGetNamespaces
	Register-ArgumentCompleter -CommandName Get-KubeResource -Parameter ResourceName -ScriptBlock $sbGetResource
	Register-ArgumentCompleter -CommandName Get-KubeResource -Parameter ItemName -ScriptBlock $sbGetItem
	Register-ArgumentCompleter -CommandName Get-KubeResource -Parameter Namespace -ScriptBlock $sbGetNamespaces
}