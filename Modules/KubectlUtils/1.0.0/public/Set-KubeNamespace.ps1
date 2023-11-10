Function Set-KubeNamespace {
    Param(
        [Parameter(Mandatory)]
        [Alias('ns')]
        [string]$Namespace
    )
    kubectl config set-context --current --namespace $Namespace
    iex ([Kube]::Initialize_KubeApiAutocomplete($true))
    Update-KubeCompletions
}
