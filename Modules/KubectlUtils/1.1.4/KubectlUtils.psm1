#$importSource = 
. "$PSScriptRoot/private/Measure-KubeContainers.ps1"
. "$PSScriptRoot/public/Copy-KubeFile.ps1"
. "$PSScriptRoot/public/Enter-KubePod.ps1"
. "$PSScriptRoot/public/Find-MaxPodMetric.ps1"
. "$PSScriptRoot/public/Get-KubeContextInfo.ps1"
. "$PSScriptRoot/public/Get-KubeMetrics.ps1"
. "$PSScriptRoot/public/Get-KubeNodesByPod.ps1"
. "$PSScriptRoot/public/Get-KubeResource.ps1"
. "$PSScriptRoot/public/Measure-DiskIO.ps1"
. "$PSScriptRoot/public/Set-KubeContext.ps1"
. "$PSScriptRoot/public/Set-KubeNamespace.ps1"
. "$PSScriptRoot/public/Trace-KubeMetrics.ps1"
. "$PSScriptRoot/public/Update-KubeCompletions.ps1"
. "$PSScriptRoot/public/ConvertFrom-StringTable.ps1"
. "$PSScriptRoot/public/Get-KubeMappedContext.ps1"
. "$PSScriptRoot/public/Remove-KubeMappedContext.ps1"
. "$PSScriptRoot/public/Rename-KubeMappedContext.ps1"
. "$PSScriptRoot/public/Set-KubeMappedContexts.ps1"
. "$PSScriptRoot/public/Start-KubePortForward.ps1"
. "$PSScriptRoot/public/New-KubeContextSession.ps1"
. "$PSScriptRoot/public/Convert-KubeCpu.ps1"
. "$PSScriptRoot/public/Get-KubeNodeMetrics.ps1"
. "$PSScriptRoot/public/Sync-KubeMappedContexts.ps1"

#$importSource | % { . (Join-Path $PSScriptRoot $_)}

$completionDir = "$HOME/.pwsh/KubectlUtils/completion"

$kubectlAlias = 'k'

$kubectlCompletionFile = "$completionDir/kubectl.ps1"
if ( !(Test-Path $kubectlCompletionFile) -or ! (Get-item $kubectlCompletionFile).Length ) {
    if ( $PSNativeCommandArgumentPassing -eq 'Legacy' ) {
        New-Item -Path $kubectlCompletionFile -Value (kubectl completion powershell | Out-String) -Force
    } else {
        New-Item -Path $kubectlCompletionFile -Value ((kubectl completion powershell | Out-String) -replace "\+ ' ``""``""'", '+ '' ""''') -Force
    }
}

. $kubectlCompletionFile

Register-ArgumentCompleter -CommandName $kubectlAlias -ScriptBlock $__kubectlCompleterBlock

Set-Alias -name $kubectlAlias	-Value kubectl		    -Scope Global -Option AllScope

if ( Get-Command helm -ErrorAction SilentlyContinue ) {
    $helmAlias = 'he'
    $helmCompletionFile = "$completionDir/helm.ps1"
    if ( !(Test-Path $helmCompletionFile) -or ! (Get-item $helmCompletionFile).Length ) {
        if ( $PSNativeCommandArgumentPassing -eq 'Legacy' ) {
            New-Item -Path $helmCompletionFile -Value (helm completion powershell | Out-String) -Force
        } else {
            New-Item -Path $helmCompletionFile -Value ((helm completion powershell | Out-String) -replace "\+ ' ``""``""'", '+ '' ""''') -Force
        }
    }

    . $helmCompletionFile

    Register-ArgumentCompleter -CommandName $helmAlias -ScriptBlock $__helmCompleterBlock

    Set-Alias -name $helmAlias	 -Value helm	        -Scope Global -Option AllScope
}

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

#try {
#	[Kube]::Initialize_KubeApiAutocomplete($false)
#}
#catch {}

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