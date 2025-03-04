Function Set-KubeNamespace {
    Param(
        [Parameter(Mandatory)]
        [Alias('ns')]
        [KubeSingleNamespaceCompletions()]
        [string]$Namespace
    )
    $setNamespace = if ( $int = $Namespace -as [int] ) {
        [Kube]::MapIntsToNamespaces.$int
    } else {
        $Namespace
    }
    kubectl config set-context --current --namespace $setNamespace
    [Kube]::Initialize_KubeApiAutocomplete($true)
    Update-KubeCompletions
}
