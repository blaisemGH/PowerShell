using namespace System.Collections.Generic
class MaxPodMetricsView {
    [string]$Namespace
    [string]$PodName
    [string]$Container
    [float]$PeakCPU
    [float]$PeakMemoryGB
    [float]$AvgCPU
    [float]$AvgMemoryGb
}
function Find-MaxPodMetric {
    Param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [Alias('i')]
        [object[]]$InputObject,

        [ValidateSet('CPU', 'c', 'memorygb', 'm', 'mem', 'both')]
        [string]$Metric = 'both'
    )
    begin {
        $m, $CPUlabel, $memoryLabel = switch -Regex ($Metric) {
            '^t.*$' { 'CPU','PeakCPU','MemoryGB'}
            '^m.*$' { 'memorygb','CPU','PeakMemoryGB' }
            DEFAULT { $_,'PeakCPU','PeakMemoryGB' }
        }
        $out = [list[object]]@()
    }
    process {
        if ( !$InputObject ) {
            continue
        }
        ForEach ($row in $InputObject) {
            $out.Add($row)
        }
    }
    end {
        If ( $m -eq 'both' ) {
            $out | Write-Output | Group-Object Namespace, PodName, Container | ForEach-Object {
                [MaxPodMetricsView]@{
                    Namespace = ($_.Name -split', ')[0]
                    PodName = ($_.Name -split', ')[1]
                    Container = ($_.Name -split', ')[2]
                    $CPULabel = $_.Group | Sort-Object CPU -desc | select -First 1 | select -exp CPU
                    $memoryLabel = $_.Group | Sort-Object memorygb -desc | select -First 1 | select -exp memorygb -OutVariable maxMem
                    AvgCPU = $_.Group | Where-Object CPU -gt 0.25 | select -exp CPU | measure -Average | select -exp Average
                    AvgMemoryGb = $_.Group | Where-Object memorygb -gt (0.05 * ( $maxMem | select -First 1 )) | select -exp memorygb | measure -Average | select -exp Average
                }
            } | Sort-Object PodName
        }
        Else {
            $out | Group-Object PodName | % { $_.Group | Sort-Object $m -Descending | select -First 1} | Sort-Object PodName | Select-Object Date, PodName, Container, @{ l = $CPULabel; e = {$_.CPU}}, @{l = $memoryLabel; e = {$_.memoryGB}}
        }
    }
}
