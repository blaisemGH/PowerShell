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

$helmAlias = 'he'
if ( Get-Command helm -ErrorAction SilentlyContinue ) {
    if ( $PSNativeCommandArgumentPassing -eq 'Legacy' ) {
        helm completion powershell | Out-String | Invoke-Expression
    } else {
        (helm completion powershell | Out-String) -replace "\+ ' ``""``""'", '+ '' ""''' | Invoke-Expression
    }
    Register-ArgumentCompleter -CommandName $helmAlias -ScriptBlock $__helmCompleterBlock
}
Set-Alias -name $helmAlias	 -Value helm	            -Scope Global -Option AllScope

Set-Alias -Name kmax    -Value Find-MaxPodMetric		-Scope Global -Option AllScope
Set-Alias -Name kex     -Value Enter-KubePod     		-Scope Global -Option AllScope
Set-Alias -Name kcp     -Value Copy-KubeFile	    	-Scope Global -Option AllScope
Set-Alias -Name kns     -Value Set-KubeNamespace	    -Scope Global -Option AllScope
Set-Alias -Name skn     -Value Set-KubeNamespace	    -Scope Global -Option AllScope
Set-Alias -Name gkr     -Value Get-KubeResource			-Scope Global -Option AllScope
Set-Alias -Name gkc     -Value Get-KubeContextInfo		-Scope Global -Option AllScope
Set-Alias -Name skc     -Value Set-KubeContext			-Scope Global -Option AllScope
Set-Alias -Name gkm     -Value Get-KubeMetrics			-Scope Global -Option AllScope
Set-Alias -Name gknp    -Value Get-KubeNodesByPod		-Scope Global -Option AllScope
Set-Alias -Name tkm     -Value Trace-KubeMetrics		-Scope Global -Option AllScope
Set-Alias -Name gknm    -Value Get-KubeNodeMetrics		-Scope Global -Option AllScope

try {
	[Kube]::Initialize_KubeApiAutocomplete($false)
}
catch {}

#Update-KubeCompletions

if ( (Get-Module PSPrompt) -and ! (Get-Module KubectlUtils) ) {
    $getItemKubernetes = {
        param($ansi)
        try {
            $contextInfo = Get-KubeContextInfo
            $area = $contextInfo.Name
            $ns = $contextInfo.Namespace
            #[string]$nsNumber = [Kube]::MapIntsToNamespaces.GetEnumerator() | Where-Object Value -eq $ns | Select-Object -ExpandProperty Name
            if ( [Kube]::IsConfigForked ) {
                # Sets icon in yellow before reverting to original color
                "`e[36;1m$ansi ${area}: $ns" 
            } else {
                "${area}: $ns"
            }
        } catch {}
    }
    $kubePromptTemplate = @{
        Alignment = 'Right'
        ForegroundColor = 'Crimson'
        ContentFunction = $getItemKubernetes
        label = 'KubectlUtilsSetContext'
        UniqueId = 69
    }
    #$align = $kubePromptTemplate.Alignment
    #if ( [PSPromptConfig]::"PromptConfigs$align".Values.UniqueId -eq $kubePromptTemplate.UniqueId ) {
        [PSPromptConfig]::AddTemplate($kubePromptTemplate)
    #}
}

if ( !(Test-Path ([Kube]::ContextFile)) ) {
    New-Item ([Kube]::ContextFile) -Value '@{}' -Force
}

# Define PatternsToRemove and use this function to housekeep your kubectl config file + local mappings
#Remove-KubeMappedContexts -PatternsToRemove <>