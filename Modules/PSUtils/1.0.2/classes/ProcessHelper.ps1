using namespace System.Diagnostics
using namespace System.Management.Automation

<#
    Starts a process using [System.Diagnostics.Process] and runs it asynchronously, writing stderr and stdout asynchronously.
    Syntax: [ProcessHelper]::new($command).Run()
    
    The constructor takes a complete string of your command, or you can provide it in 2 arguments, e.g., new($executable, $args),
    where $args will be joined into a single string if not provided as such.

    The method Run can also take a scriptblock to track the progress of the command. The scriptblock should contain all
    of the logic to determine the current progress, and it should return a value less than 1. The method will round it to
    4 decimal places and multiply it by 100 to convert to units %. If the resulting number is over 100, then it
    will assume a percentage was already input and divide by 100 to compensate. 
#>
class ProcessHelper {
    [string]$Executable
    [string]$SubmitArgs
    [string]$Command
    [bool]$UseShellExecute

    ProcessHelper([string]$FullCommand) {
        $this.executable, $this.submitArgs = $FullCommand -split ' ', 2
        $this.Set_ShellExecute($this.executable)
        $this.Command = $FullCommand
    }
    ProcessHelper([string]$executable, [string[]]$submitArgs) {
        $this.Set_ShellExecute($executable)
        $this.Executable = $executable
        $this.SubmitArgs = $submitArgs -join ' '
        $this.Command = "$($this.Executable) $($this.SubmitArgs)"
    }

    [void]Set_ShellExecute([string]$executable) {
        if ( (Test-Path $executable) -or (Test-Path (Get-Command $executable).Source )) {
            $this.UseShellExecute = $false
        }
        elseif ( Get-Command $executable ) {
            $this.UseShellExecute = $true
        }
        else {
            $err = [ErrorRecord]::new( "Executable provided was not found as a command or filepath to an executable. Input executable: $Executable", $null, 'CommandNotFoundException', $null)
            throw $err
        }
    }

    [Process] Run () {
        return $this.Start_Process($this.Initialize())
    }

    [Process] Run ([ScriptBlock]$TrackProgress) {
        return $this.Start_Process($this.Initialize(), $TrackProgress)
    }

    [Process] Initialize () {
            $processInfo = [ProcessStartInfo]::new( $this.executable, $this.submitArgs )
            $processInfo.RedirectStandardError	= $true
            $processInfo.RedirectStandardOutput	= $true
            $processInfo.StandardOutputEncoding	= [System.Text.Encoding]::GetEncoding('UTF-8')
            $processInfo.StandardErrorEncoding	= [System.Text.Encoding]::GetEncoding('UTF-8')
            $processInfo.UseShellExecute = $this.UseShellExecute
            
            $Process = [Process]::new()
            $Process.StartInfo = $processInfo
            return $Process 
    }

	# Invokes the actual process start and submission to the executable.
	[Process] Start_Process ( [Process]$Process ) {
		try {
			Write-Debug ('Activating async logging{0}' -f [Environment]::NewLine)
			[ProcessHelper]::Initialize_ProcessOutputWatcher($Process)
			$Process.Start()
			$Process.BeginErrorReadline()  #Asynchronous streaming of stderr from the process
			$Process.BeginOutputReadLine() #Asynchronous streaming of stdout from the process
			$Process.WaitForExitAsync()
		}
		finally {
			Unregister-Event -SourceIdentifier 'ErrorHandler'
			Unregister-Event -SourceIdentifier 'OutputHandler'
		}
		return $Process
	}

    	# Invokes the actual process start and submission to the executable.
	[Process] Start_Process ( [Process]$Process, [scriptblock]$TrackProgress) {
		try {
			Write-Debug ('Activating async logging{0}' -f [Environment]::NewLine)
			[ProcessHelper]::Initialize_ProcessOutputWatcher($Process)
			$Process.Start()
			$Process.BeginErrorReadline()  #Asynchronous streaming of stderr from the process
			$Process.BeginOutputReadLine() #Asynchronous streaming of stdout from the process
            $stopWatch = [System.Diagnostics.Stopwatch]::StartNew()

			while ( -Not $Process.HasExited ) {
                $progressPercent = [Math]::Round((& $TrackProgress), 4) * 100
                if ( $progressPercent -gt 100 ) { # Just checking if $TrackProgress already delivers the numbers in %,
                    $progressPercent = $progressPercent / 100 # in which case my `* 100` two lines up needs to be undone via `/ 100`.
                }
                if ( $progressPercent -ge 0.5 ) {
                    $estimateRemainingSeconds = ((100 / $progressPercent ) - 1 ) * $stopWatch.Elapsed.Seconds
                    Write-Progress -PercentComplete $progressPercent -Activity $this.Command -Status "${progressPercent}% complete" -SecondsRemaining $estimateRemainingSeconds
                }
                
				Start-Sleep -Seconds 3
			}
		}
		finally {
            $stopWatch = $null # Do I even need to clean this up or even stop it at all?
			Unregister-Event -SourceIdentifier 'ErrorHandler'
			Unregister-Event -SourceIdentifier 'OutputHandler'
		}
		return $Process
	}

    static [void] Initialize_ProcessOutputWatcher ([Process]$Process) {
		$Global:jobLogStream = [PSDataCollection[String]]::new()  #The PSDataCollection is a more complicated way to do this, but it is thread safe for asynchronous data collecting. Not sure if this matters, but I kept it just in case.
		$Global:jobLogStream.add_DataAdded(
			{
				$line = $this[0]
				Write-Host $line
				$this.Remove($line)
			}
		)
		$sbAction = { param([object]$Sender, [DataReceivedEventArgs]$EventArgs)
			$Global:jobLogStream.Add($EventArgs.Data)
		}


		Register-ObjectEvent -InputObject $Process -Action $sbAction -EventName OutputDataReceived -SourceIdentifier 'OutputHandler'
		Register-ObjectEvent -InputObject $Process -Action $sbAction -EventName ErrorDataReceived -SourceIdentifier 'ErrorHandler'

	}

}