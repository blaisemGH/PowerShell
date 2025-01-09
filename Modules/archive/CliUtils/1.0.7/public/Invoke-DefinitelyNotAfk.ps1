function Invoke-DefinitelyNotAfk {
    while($true) {
        $wsh = New-Object -ComObject WScript.Shell
        $wsh.SendKeys('+{F15}')
        Start-Sleep -seconds 15
    }
}
