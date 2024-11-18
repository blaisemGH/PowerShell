using namespace System.Management.Automation

class KubeResourceTransform : ArgumentTransformationAttribute {
    static $shortcuts = @{
        c = 'configmaps'
        cm = 'configmaps'
        cj = 'cronjobs.batch'
        cr = 'clusterroles.rbac.authorization.k8s.io'
        crb = 'clusterrolebindings.rbac.authorization.k8s.io'
        d = 'deployments.apps'
        deploy = 'deployments.apps'
        ds = 'daemonsets.apps'
        e = 'events'
        i = 'ingresses.networking.k8s.io'
        j = 'jobs.batch'
        n = 'namespaces'
        ns = 'namespaces'
        no = 'nodes'
        p = 'pods'
        pv = 'persistentvolumes'
        pvc = 'persistentvolumeclaims'
        rb = 'rolebindings.rbac.authorization.k8s.io'
        ro = 'roles.rbac.authorization.k8s.io'
        rs = 'replicasets.apps'
        sa = 'serviceaccounts'
        s = 'statefulsets.apps'
        se = 'secrets'
        sts = 'statefulsets.apps'
        svc = 'services'
    }

    [object] Transform([EngineIntrinsics]$engineIntrinsics, [object] $inputData) {
        $transform = if ([KubeResourceTransform]::shortcuts.Contains($inputData)) { [KubeResourceTransform]::shortcuts.$inputData } else {$inputData}

        $resourceMatches = [Kube]::FullApiResources | where {
            if ( $_.APIVERSION ) {    
                ($_.NAME + '.' + $_.APIVERSION) -match "$transform.*"
            } else {
                $_.NAME -match "$transform.*"
            }
        } | Select-Object NAME, APIVERSION

        [string[]$resourceName, $apiVersion = $resourceMatches.NAME, $resourceMatches.APIVERSION

        if ($resourceName.Count -gt 1 ) {
            Throw "Could not resolve ambiguous resource.`nDid you mean 1 of $($resourceName)"
        }
        if ( $resourceName.Count -eq 0 ) {
            Throw "Could not match $inputData to an existing kubectl resource."
        }

        if ( $apiVersion ) {
            return $resourceName + '.' + $apiVersion
        }
        return $resourceName
    }
}