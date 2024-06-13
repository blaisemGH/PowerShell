$kubectlAlias = 'k'
If ( Get-Command kubectl -ErrorAction SilentlyContinue ) {
    if ( $PSNativeCommandArgumentPassing -eq 'Legacy' ) {
        kubectl completion powershell | Out-String | Invoke-Expression
    } else {
        (kubectl completion powershell | Out-String) -replace "\+ ' ``""``""'", '+ '' ""''' | Invoke-Expression
    }
	Register-ArgumentCompleter -CommandName $kubectlAlias -ScriptBlock $__kubectlCompleterBlock
}
Set-Alias -name $kubectlAlias	-Value kubectl		    -Scope Global -Option AllScope

Set-Alias -Name kmax    -Value Find-MaxPodMetric		-Scope Global -Option AllScope
Set-Alias -Name kex     -Value Enter-KubePod     		-Scope Global -Option AllScope
Set-Alias -Name kcp     -Value Copy-KubeFile	    	-Scope Global -Option AllScope
Set-Alias -Name kns     -Value Set-KubeNamespace	    -Scope Global -Option AllScope
Set-Alias -Name gkd     -Value Get-KubeDeployList		-Scope Global -Option AllScope
Set-Alias -Name gks     -Value Get-KubeStatefulSetList	-Scope Global -Option AllScope
Set-Alias -Name gkp     -Value Get-KubePodList			-Scope Global -Option AllScope
Set-Alias -Name gkr     -Value Get-KubeResource			-Scope Global -Option AllScope
Set-Alias -Name gkc     -Value Get-KubeContext			-Scope Global -Option AllScope
Set-Alias -Name skc     -Value Set-KubeContext			-Scope Global -Option AllScope
Set-Alias -Name gkm     -Value Get-KubeMetrics			-Scope Global -Option AllScope
Set-Alias -Name gknp    -Value Get-KubeNodesByPod		-Scope Global -Option AllScope

try {
	Invoke-Expression ([Kube]::Initialize_KubeApiAutocomplete($false))
}
catch {}

Update-KubeCompletions
