using namespace System.Collections.Generic
using namespace System.Management.Automation
function Set-GCloudGkeContext {
    param(
        [Paramater(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$ProjectId
    )
    begin {
        $projectIdSet = [Hashset[string]]::new()
        [HashSet[string]]$localFileProjectIds = Get-ChildItem ([GCloud]::ProjectRoot) -Recurse -File | Select-Object -ExpandProperty Name
        [HashSet[string]]$mappedProjectIds = [Kube]::MappedContexts.Values
        [HashSet[string]]$kubeContexts = kubectl config get-contexts -o name
        $projectIdSet.UnionWith($localFileProjectIds)
        $projectIdSet.UnionWith($mappedProjectIds)
        $projectIdSet.UnionWith($kubeContexts)
    }
    process {
        [string[]]$gkeContext = $projectIdSet | where { $_ -eq $ProjectId } | Sort-Object -Unique
    }
    end {
        if ( $gkeContext.Count -gt 1 ) {
            $err = [ErrorRecord]::new("Error: More than 1 gkeContext was found for project $ProjectId", $null, 'InvalidResult', $null)
            $PSCmdlet.ThrowTerminatingError($err)
        }

        Set-KubeContext -Context $gkeContext
    }

}