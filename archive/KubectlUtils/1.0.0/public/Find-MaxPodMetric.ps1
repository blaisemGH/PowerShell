Function Find-MaxPodMetric {
    Param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [Alias('i')]
        [object[]]$InputObject,
        [ValidateSet('threads', 't', 'memorygb', 'm', 'mem', 'both')]
        [string]$Metric = 'threads',
        [ValidateSet('PodMetrics','OnlyRelevantPodMetrics')]
        [string]$Property = 'OnlyRelevantPodMetrics'
    )
    begin {
        $m, $threadslabel, $memoryLabel = switch -Regex ($Metric) {
            '^t.*$' { 'threads','PeakThreads','MemoryGB'}
            '^m.*$' { 'memorygb','Threads','PeakMemoryGB' }
            DEFAULT { $_,'PeakThreads','PeakMemoryGB' }
        }
        $out = [list[object]]@()
    }
    process {
        ForEach ($row in $InputObject) {
            $out.Add($row)
        }
    }
    end {
        If ( $m -eq 'both' ) {
            $out.$Property | Group-Object PodName | % {
                [PSCustomObject]@{
                    PodName = $_.Name
                    $threadsLabel = $_.Group | Sort-Object threads -desc | select -First 1 | select -exp threads
                    $memoryLabel = $_.Group | Sort-Object memorygb -desc | select -First 1 | select -exp memorygb -OutVariable maxMem
                    AvgThreads = $_.Group | Where-Object threads -gt 0.25 | select -exp threads | measure -Average | select -exp Average
                    AvgMemoryGb = $_.Group | Where-Object memorygb -gt (0.05 * ( $maxMem | select -First 1 )) | select -exp memorygb | measure -Average | select -exp Average
                }
            } | Sort-Object PodName
        }
        Else {
            $out.$Property | Group-Object PodName | % { $_.Group | Sort-Object $m -Descending | select -First 1} | Sort-Object PodName | select Date, PodName, Container, @{ l = $threadsLabel; e = {$_.Threads}}, @{l = $memoryLabel; e = {$_.memoryGB}}
        }
    }
}
