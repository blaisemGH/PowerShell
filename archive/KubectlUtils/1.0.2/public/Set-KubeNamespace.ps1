Function Set-KubeNamespace {
    Param(
        [Parameter(Mandatory)]
        [Alias('ns')]
        [string]$Namespace
    )
    $setNamespace = if ( $int = $Namespace -as [int] ) {
        [Kube]::MapIntsToNamespaces.$int
    } else {
        $Namespace
    }
    kubectl config set-context --current --namespace $setNamespace
    Invoke-Expression ([Kube]::Initialize_KubeApiAutocomplete($true))
    Update-KubeCompletions
}
