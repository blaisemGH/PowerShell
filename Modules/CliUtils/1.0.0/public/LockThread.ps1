<#
	.SYNOPSIS
		This is a set of functions to bind/unbind a thread to your PS session. A bound thread causes Windows to view it as active and prevents sleep. This is useful for long-running processes where you don't want your computer to fall asleep after the default timeout but also don't want to change the default setting for said timeout.
		
		WARNING: You MUST deactivate this thread or otherwise close your PS session to allow your computer to fall asleep again. If you have a laptop, you cannot simply close the laptop and expect it to fully go to sleep. It will seem to fall asleep, but that single thread will still be active and this will generate noticeable heat in closed spaces, which over time may have adverse effects.
#>
Function Start-LockThread {
    #Load the Windows API from a specified dll - here Kernel32.dll
    $function=@' 
[DllImport("kernel32.dll", CharSet = CharSet.Auto,SetLastError = true)]
 public static extern void SetThreadExecutionState(uint esFlags);
'@

    $global:LockThread = Add-Type -MemberDefinition $function -name System -namespace Win32 -passThru 

    #Specify the flags to use them later 
    $ES_CONTINUOUS = [uint32]'0x80000000'
    $ES_AWAYMODE_REQUIRED = [uint32]'0x00000040'
    $ES_DISPLAY_REQUIRED = [uint32]'0x00000002'
    $ES_SYSTEM_REQUIRED = [uint32]'0x00000001'

    $global:LockThread::SetThreadExecutionState($ES_CONTINUOUS -bor $ES_DISPLAY_REQUIRED -bor $ES_AWAYMODE_REQUIRED )
	Write-Host 'Locking thread to this PS session.'
}

Function Stop-LockThread {
    #Load the Windows API from a specified dll - here Kernel32.dll
    $function=@' 
[DllImport("kernel32.dll", CharSet = CharSet.Auto,SetLastError = true)]
 public static extern void SetThreadExecutionState(uint esFlags);
'@

	If ( !$global:LockThread ) {
		$global:LockThread = Add-Type -MemberDefinition $function -name System -namespace Win32 -passThru 
	}

    #Specify the flags to use them later 
    $ES_CONTINUOUS = [uint32]'0x80000000'
    $ES_AWAYMODE_REQUIRED = [uint32]'0x00000040'
    $ES_DISPLAY_REQUIRED = [uint32]'0x00000002'
    $ES_SYSTEM_REQUIRED = [uint32]'0x00000001'

    $global:LockThread::SetThreadExecutionState($ES_CONTINUOUS)
	Write-Host 'Unlocking thread to this PS session.'
}