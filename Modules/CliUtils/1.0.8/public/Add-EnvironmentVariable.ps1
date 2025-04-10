using namespace System.IO
using namespace System.Security.Principal

function Add-EnvironmentVariable {
    param(
        # Name of environment variable to add
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        $Value,

        # Sets the environment variable according to the given scope.
        # Process sets the variable in the current session only.
        # If outside of Windows, User adds to bashrc and Machine adds to /etc/environment.
        [ValidateSet('Process','User','Machine')]
        $Scope = 'Process',

        [switch]$Force
    )
    $ErrorActionPreference = 'Stop'
    $setEnvParams = [hashtable]$PSBoundParameters
    $setEnvParams.Scope = $Scope
    $setEnvParams.Force = $Force
    $setEnvParams.IsAdmin = Test-HasAdminPrivileges

    $currentEnvVarValue = [Environment]::GetEnvironmentVariable($Name, $setEnvParams.Scope)

    # Setup things for Path environment variables
    $isPathVariable = if ( $Name -match 'Path' -and $Name -ne 'PATH' ) {
            $out = Test-ReadHost -Query 'Is this a PATH variable?' -ValidationStrings 'Y','N'
            if ($out -eq 'Y') {$true} else {$false}
        } elseif ($Name -eq 'PATH') {
            $true
        } else {
            $false
        }

    if ( $isPathVariable ) {

        [string[]]$currentPaths = & {
            if ( $env:OS -match 'Windows' -and $Scope -ne 'Process') {
                try {
                    $key = switch ($Scope) {
                        Machine {
                            [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey(
                                'SYSTEM\CurrentControlSet\Control\Session Manager\Environment',
                                $true # Write access
                            )
                        }
                        User { [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey( 'Environment', $true ) }
                    }

                    $key.GetValue('Path', $null, 'DoNotExpandEnvironmentNames').TrimEnd([IO.Path]::PathSeparator)
                } finally {
                    if ($null -ne $key) {
                        $key.Dispose()
                    }
                }
            }
            else {
                $currentEnvVarValue -split ([Path]::PathSeparator) | where {$_}
            }
        }
        # Account for a $Value that contains multiple paths and the OS-specific path delimiter 
        $setEnvParams.Value = & {
            if ( $Value -match [Path]::PathSeparator ) {
                $Value -split [Path]::PathSeparator | Where {$_}
            }
            else { # Filter out null in case $Value is an array of paths
                [string[]]$Value | Where {$_}
            }
        }

        if ( $env:OS -match 'Windows' ) {
            # Checks if the path is already defined in the complementary scope and prompts whether to remove it from that scope.
            $companionScopeValues = Format-UniqueWindowsPaths @setEnvParams
        }
    }

    # Confirm set if environment variable already has a value
    $confirm = & {
        if ( $currentPaths | where {$_ -in $setEnvParams.Value} ) {
            Write-Warning "Environment Variable $Name already contains value $Value."
            Test-ReadHost "Do you wish to move the path up to the head of your paths? [y/n]" -ValidationStrings 'y', 'n' -default 'n'
        }
        elseif ($currentEnvVarValue -and !$Force -and $Name -notmatch 'Path') {
            Write-Warning "Environment Variable $Name has value: $Value"
            Test-ReadHost -Query 'Do you wish to overwrite it? [y/n]' -ValidationStrings 'y', 'n' -DefaultResponse 'n'
        }
    }

    # Set environment variable
    if ( $confirm -ne 'n' ) {
        $setEnvParams.Value = Get-EnvironmentVariableValue -Name $Name -Value $setEnvParams.Value -CurrentPaths $currentPaths
        Export-EnvironmentVariable @setEnvParams -WindowsCompanionScopePathValues $companionScopeValues
        Write-Host "Environment Variable $Name updated to $($setEnvParams.Value)" -Fore Green
    }
    else {
        Write-Warning "Declined to update Environment Variable $Name with value $Value. Nothing to do. Ending function with no action."
    }
}

function Test-HasAdminPrivileges {
    if ( $env:OS -match 'Windows' ) {
        $currentUserElevation = [WindowsIdentity]::GetCurrent()
        return [WindowsPrincipal]::new($currentUserElevation).
            IsInRole([WindowsBuiltinRole]::Administrator)
    }
    else {
      #$userId = . id -u
      #return (! [bool]$userID )
      if ( eval "groups | grep sudo" ) {
          return $true
      }
    }
    return $false
}

function Get-EnvironmentVariableValue {
    [CmdletBinding(DefaultParameterSetName='NotPathVariable')]
    [OutputType([String])]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [string[]]$Value,
        [Parameter(Mandatory,ParameterSetName='PathVariable')]
        [string[]]$currentPaths
    )
    if ( $PSCmdlet.ParameterSetName -eq 'PathVariable' ) {
        return $Value + $currentPaths -join [Path]::PathSeparator
    }
    else {
        return [string]$Value
    }
}

function Export-EnvironmentVariable {
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [string]$Value,
        [Parameter(Mandatory)]
        [ValidateSet('Process','User','Machine')]
        [string]$Scope,
        [Parameter(Mandatory)]
        [switch]$IsAdmin,
        [string]$WindowsCompanionScopePathValues
    )

    if ( $Scope -eq 'Machine' -and !$isAdmin ) {
        $errMsg = "Your desired scope is 'Machine', but this session does not have administrator privileges!" + [Environment]::NewLine +
            'Rerun this function with administrative privileges available'
        $err = New-ErrorRecord $errMsg
        $PSCmdlet.ThrowTerminatingError($err)
    }

    $updateEnvFile = {
        if ( Select-String -Path $envFile -Pattern $searchVar ) {
            (Get-Content $envFile | foreach {
                $_ -replace $searchVar, $setVar
            }) | Set-Content $envFile
        } else {
            Add-Content -Path $envFile -Value $setVar
        }
    }

    if ( $env:OS -match 'Windows' ) {

        [Environment]::SetEnvironmentVariable($Name, $Value, $Scope)
        if ( $WindowsCompanionScopePathValues -and $Scope -eq 'Machine' ) {
            try {
                $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey(
                    'SYSTEM\CurrentControlSet\Control\Session Manager\Environment',
                    $true # Write access
                )
                $key.SetValue('Path', $Value, 'ExpandString')
            } finally {
                if ($null -ne $key) {
                    $key.Dispose()
                }
            }
            $updateSessionValue = $WindowsCompanionScopePathValues + [Path]::PathSeparator + $Value
        }
        elseif ($WindowsCompanionScopePathValues -and $Scope -eq 'User') {
            try {
                $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment', $true)
                $key.SetValue('Path', $Value, 'ExpandString')
            } finally {
                if ($null -ne $key) {
                    $key.Dispose()
                }
            }
            $updateSessionValue = $Value + [Path]::PathSeparator + $WindowsCompanionScopePathValues
        }
        else {
            $updateSessionValue = $Value
        }
        [Environment]::SetEnvironmentVariable($Name, $updateSessionValue, 'Process')
    }
    else {
        switch ($Scope) {
            User {
                $envFile = Convert-Path ~/.bashrc
                $searchVar = "^export\s+$Name=.*"
                $setVar = "export $Name=$Value"
                & $updateEnvFile
            }
            Machine {
                $envFile = Convert-Path ~/.bashrc
                $searchVar = "$Name=.*"
                $setVar = "$Name=$Value"
                & $updateEnvFile
            }
        }
        export $Name=$Value
    }
}

function Format-UniqueWindowsPaths {
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [string[]]$Value,
        [Parameter(Mandatory)]
        [ValidateSet('Process','User','Machine')]
        [string]$Scope,
        [Parameter(Mandatory)]
        [switch]$IsAdmin
    )
    if ( $env:OS -match 'Windows' ) {
        $companionScope = switch ($Scope) {
            'User' { 'Machine' }
            'Machine' { 'User' }
            'Process' { 'Process' }
        }
        $companionScopeValues = [Environment]::GetEnvironmentVariable($Name, $companionScope) -split [Path]::PathSeparator
        $overlappingValues = $companionScopeValues | Where { $_ -in $Value }
        $filteredCompanionValues = ($companionScopeValues | Where { $_ -notin $Value }) -join [Path]::PathSeparator

        $exit = $null
        $confirm = $null
        if ( $overlappingValues -and $companionScope -in 'User', 'Machine') {
            if ( $companionScope -eq 'Machine' -and !$IsAdmin) {
                Write-Warning "Path $Value is already present for $Name in the System scope, but you do not have admin privileges to change it."
                $exit = Test-ReadHost "Do you wish to continue this function and duplicate this path value in your scope?" -ValidationStrings 'y','n'
            }
            else {
                Write-Warning "Path $value is already present for $Name in a different scope: $companionScope."
                $confirm = Test-ReadHost "Do you wish to remove the redundant $Value from $Name in scope $companionScope?" -ValidationStrings 'y','n'
            }
        }

        if ( $confirm -eq 'y' ) {
            [Environment]::SetEnvironmentVariable($Name, $filteredCompanionValues, $companionScope)
            Write-Host "$Value removed from $Name in scope $companionScope"
        }
        if ( $exit -eq 'y' ) {
            $err = New-ErrorRecord 'Voluntarily ended function due to duplicate value in other scope.'
            $PSCmdlet.ThrowTerminatingError($err)
        }
        return $companionScopeValues -join [Path]::PathSeparator
    }
}