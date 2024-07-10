function Get-KubeMappedContext {
    [CmdletBinding(DefaultParameterSetName='allContexts')]
    param (
        [Parameter(Mandatory,ParameterSetName='singleContext')]
        [KubeMappedContextsCompletions()]
        [alias('Context','c')]
        [string]$KubeContext,

        [Parameter(ParameterSetName='allContexts')]
        [switch]$all
    )
    if ( $PSCmdlet.ParameterSetName -eq 'singleContext' ) { 
        [Kube]::MappedContexts.$KubeContext
    }
    else {
        [Kube]::MappedContexts
    }
}