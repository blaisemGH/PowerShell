using namespace System.Collections.Generic
using namespace System.Management.Automation.Runspaces
using namespace System.Collections.Specialized

class RunspaceRunnerOrderedEntry {
    [string]$MarkId
    [string[]]$Arguments
    [initialsessionstate]$Iss
}
class RunspaceRunner {
    [RunspacePool]$RunspacePool
    [list[PSCustomObject]]$RunspaceInvocations = @()
    [scriptblock] $Scriptblock
    [int]$Parallelism = 1
    [int]$Id = 0
    [InitialSessionState]$InitialSessionState

    RunspaceRunner ([scriptblock]$sb) {
        $this.Scriptblock = $sb
        $this.Parallelism = (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors
        $this.RunspacePool = [RunspaceFactory]::CreateRunspacePool(1, $this.Parallelism)
        $this.RunspacePool.Open()
    }

    RunspaceRunner ([scriptblock]$sb, [int]$parallelism) {
        $this.Scriptblock = $sb
        $this.Parallelism = [Math]::Max(1, $parallelism)
        $this.RunspacePool = [RunspaceFactory]::CreateRunspacePool(1, $this.Parallelism)
        $this.RunspacePool.Open()
    }

    RunspaceRunner ([InitialSessionState]$iss, [scriptblock]$sb) {
        $this.InitialSessionState = $iss
        $this.Scriptblock = $sb
        $this.Parallelism = (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors
        $this.RunspacePool = [RunspaceFactory]::CreateRunspacePool(1, $this.Parallelism)
        $this.RunspacePool.Open()
    }

    RunspaceRunner ([InitialSessionState]$iss, [scriptblock]$sb, [int]$parallelism) {
        $this.InitialSessionState = $iss
        $this.Scriptblock = $sb
        $this.Parallelism = [Math]::Max(1, $parallelism)
        $this.RunspacePool = [RunspaceFactory]::CreateRunspacePool(1, $this.Parallelism)
        $this.RunspacePool.Open()
    }

    [int] Start_NewRunspace () {
        If ( $this.InitialSessionState) {
            $instancePS    = [PowerShell]::Create($this.InitialSessionState)
        }
        Else {
            $instancePS    = [PowerShell]::Create()
        }
        $instancePS.RunspacePool = $this.RunspacePool

        $instancePS.AddScript($this.Scriptblock)

        $this.RunspaceInvocations.Add(
            [PSCustomObject]@{
                id = $this.Id += 1
                rsProcess = $instancePS
                handle = $instancePS.BeginInvoke()
            }
        )
        return $this.Id
    }

    [int] Start_NewRunspace ([string[]] $arguments) {
        If ( $this.InitialSessionState) {
            $instancePS    = [PowerShell]::Create($this.InitialSessionState)
        }
        Else {
            $instancePS    = [PowerShell]::Create()
        }
        $instancePS.RunspacePool = $this.RunspacePool

        $instancePS.AddScript($this.Scriptblock)
        Foreach ( $arg in $arguments ) {
            $instancePS.AddArgument($arg)
        }
        
        $this.RunspaceInvocations.Add(
            [PSCustomObject]@{
                id = $this.Id += 1
                rsProcess = $instancePS
                handle = $instancePS.BeginInvoke()
            }
        )
        return $this.Id
    }

    [int] Start_NewRunspace ([InitialSessionState]$iss) {
        $instancePS    = [PowerShell]::Create($iss)
        $instancePS.RunspacePool = $this.RunspacePool

        $instancePS.AddScript($this.Scriptblock)

        $this.RunspaceInvocations.Add(
            [PSCustomObject]@{
                id = $this.Id += 1
                rsProcess = $instancePS
                handle = $instancePS.BeginInvoke()
            }
        )
        return $this.Id
    }

    [int] Start_NewRunspace ([InitialSessionState]$iss, [string[]] $arguments) {
        $instancePS    = [PowerShell]::Create($iss)
        $instancePS.RunspacePool = $this.RunspacePool

        $instancePS.AddScript($this.Scriptblock)
        Foreach ( $arg in $arguments ) {
            $instancePS.AddArgument($arg)
        }
        
        $this.RunspaceInvocations.Add(
            [PSCustomObject]@{
                id = $this.Id += 1
                rsProcess = $instancePS
                handle = $instancePS.BeginInvoke()
            }
        )
        return $this.Id
    }


    [Object[]] Receive_RunspaceOutput () {
        $output = [PSCustomObject]@{}
        #$removeIds = [list[int]]@()
        If ( $this.RunspaceInvocations.handle ) {
			While ( $this.RunspaceInvocations.handle.IsCompleted -Contains $false) {
            }
            If ( $this.RunspaceInvocations.handle.IsCompleted -Contains $true ) {
                $output = ForEach ( $invocation in $this.RunspaceInvocations | Where {$_.Handle.IsCompleted} ) {
                    [PSCustomObject]@{
                        stdout = $invocation.rsProcess.EndInvoke($invocation.handle)
                        stderr = If ( $invocation.rsProcess.HadErrors -eq 'True' ){$invocation.rsProcess.streams.error}
                    }
                    #$removeIds.Add($invocation.Id)
                }
                $this.RunspaceInvocations = @()
            }
        }
        return $output
    }

    [PSCustomObject] Receive_RunspaceOutput ([int]$id) {
        $output = [PSCustomObject]@{}
        $runspace = $this.RunspaceInvocations | Where Id -eq $id
        If ( $runspace.handle ) {
			While ( $runspace.handle.IsCompleted -Contains $false) {
            }
            If ( $runspace.handle.IsCompleted -Contains $true ) {
                $output = [PSCustomObject]@{
                    stdout = $runspace.rsProcess.EndInvoke($runspace.handle)
                    stderr = If ( $runspace.rsProcess.HadErrors -eq 'True' ){$runspace.rsProcess.streams.error}
                }
            }
            $this.RunspaceInvocations = $this.RunspaceInvocations.where({ $_.id -ne $id })
            If ( !$this.RunspaceInvocations ) {
                $this.RunspaceInvocations = @()
            }
        }
        return $output
    }

    [int] StartRunspaceEntry([RunspaceRunnerOrderedEntry]$entry) {
        return $(
            if ( $entry.iss -and !$entry.Arguments ) {$this.Start_NewRunspace($entry.iss)}
            elseif ( $entry.Arguments -and !$entry.iss) {$this.Start_NewRunspace($entry.Args)}
            elseif ( $entry.Iss -and $entry.Arguments) {$this.Start_NewRunspace($entry.iss, $entry.Args)}
            else { $this.runspaceRunner.Start_NewRunspace() }
        )
    }

    [OrderedDictionary]InvokeAllInOrder([List[Hashtable]]$orderedItems) {
        $orderedOutput = [ordered]@{}
        $trackConcurrency = @{}
        foreach ($entry in $orderedItems ) {
            if ((Get-Runspace).Count -lt $this.parallelism) {
                $runId = $this.StartRunspaceEntry($entry)
                $trackConcurrency.Add( $runId, $entry.MarkId )
            } else {
                while ( $this.RunspaceInvocations.handle.IsCompleted -NotContains $true) {}
              
                $finishedId = $this.RunspaceInvocations | where {$_.handle.IsCompleted} | Select-Object -ExpandProperty id
                $commandCompletions = $this.Receive_RunspaceOutput($finishedId)
                $command = $trackConcurrency.$finishedId
              
                $orderedOutput.Add($command, $commandCompletions)
              
                $trackConcurrency.Remove($finishedId)
    
                $trackConcurrency.Add( [void]$this.StartRunspaceEntry($entry), $command )
            }
        }

        return $orderedOutput
    }
    
    [void] Close () {
        $this.RunspacePool.Close()
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
    }
    [void] Dispose () {
        $this.RunspacePool.Dispose()
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
    }
}
