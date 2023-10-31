Function Get-KubeMetrics {
	Param(
		[string[]]$Namespaces = ( kubectl get serviceaccounts default -o jsonpath='{.metadata.namespace}' )
	)
	$date = Get-Date
	$metrics = & {
		kubectl get --raw "/apis/metrics.k8s.io/v1beta1/pods" |
		ConvertFrom-Json |
		select -Exp items | 
		where {
			$_.metadata.namespace -in $Namespaces
		}
	}
	return (
		[PSCustomObject]@{
			Date = $date
			PodMetrics = $(
				Foreach ($ns in $Namespaces) {
					$metrics | Where {
						$_.metadata.namespace -eq $ns
					} | ForEach-Object {
						$_ | Measure-KubeContainers -Namespace $_.metadata.namespace -PodName $_.metadata.name
					}
				}
			)
			OnlyRelevantPodMetrics = (
				$metrics | ForEach-Object {
					$ns = $_.metadata.namespace
					$pod = $_.metadata.name
					$_.containers |
					where {
						(
							[HashSet[string]]$_.name).Overlaps(
								[Kube]::relevantContainers
						)
					} | ForEach-Object {
						Measure-KubeContainers -Containers $_ -Namespace $ns -PodName $pod
					}
				}
			)
		}
	)
}