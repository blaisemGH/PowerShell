try {
	iex ([Kube]::Initialize_KubeApiAutocomplete($false))
}
catch {}

Set-Alias -Name kmax -Value Find-MaxPodMetric		-Scope Global -Option AllScope
Set-Alias -Name kex	-Value Enter-KubePod			-Scope Global -Option AllScope
Set-Alias -Name kcp	-Value Copy-KubeFile			-Scope Global -Option AllScope
Set-Alias -Name kns	-Value Set-KubeNamespace		-Scope Global -Option AllScope
Set-Alias -Name gkd	-Value Get-KubeDeployList		-Scope Global -Option AllScope
Set-Alias -Name gks	-Value Get-KubeStatefulSetList	-Scope Global -Option AllScope
Set-Alias -Name gkp	-Value Get-KubePodList			-Scope Global -Option AllScope
Set-Alias -Name gkr	-Value Get-KubeResource			-Scope Global -Option AllScope
Set-Alias -Name gkc	-Value Get-KubeContext			-Scope Global -Option AllScope
Set-Alias -Name skc	-Value Set-KubeContext			-Scope Global -Option AllScope


Update-KubeCompletions
