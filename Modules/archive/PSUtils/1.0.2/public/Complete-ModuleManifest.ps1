function Complete-ModuleManifest {
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateScript({
            if ((Get-Module $_) -or (Import-Module $_)) {
                $true
            }
            else {
                Write-Error "FATAL: Module $_ was not found by Get-Module or able to be imported by Import-Module."
            }
        })]
        [string]$Module
    )
    $odir = $PWD.Path
    $modulePath = Get-Module $Module | Select-Object -ExpandProperty ModuleBase
    try {
        $moduleFile = Get-Item $modulePath/*psd1 -ErrorAction Stop | Select-Object -ExpandProperty FullName
    } catch {
        $err = [ErrorRecord]::new("No preexisting module manifest file found in path $modulePath/*psd1. This is required! Found error: $_", $null, 'ObjectNotFound', $null)
        $PSCmdlet.ThrowTerminatingError($err)
    }

    $updateParams = @{}
    try {
        cd $modulePath

        # Will need a sort dependencies function here
        $updateParams.scriptsToProcess = (gci -Recurse -File -Filter *ps1 | sort Directory | select -exp FullName | Resolve-Path -Relative | % { "'$_'" -join ',' })
        $updateParams.fileList = (
            Get-ChildItem -Recurse -File | Resolve-Path -Relative | ForEach-Object { "'$_'" }
        ) -join ', '
        $updateParams.formatsToExport = (
            Get-ChildItem -Recurse -File -Filter *Format.ps1xml | Resolve-Path -Relative | ForEach-Object { "'$_'" }
        ) -join ', '
        $updateParams.typesToExport = (
            Get-ChildItem -Recurse -File -Filter *Type.ps1xml | Resolve-Path -Relative | ForEach-Object { "'$_'" }
        ) -join ', '
        # Requires annotation of # export above function declaration.
        # This is to distinguish from subfunction definitions that don't need to be exported
        $updateParams.functionsToExport = (
            Get-ChildItem -Recurse -File -Filter *.ps1 |
                Select-String -Pattern '(?sm)^# Export\s*[\r\n]+^\s*function\s+([^\s]+)' |
                Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Groups |
                    Where-Object Name -eq 1 |
                    Select-Object -ExpandProperty Value | ForEach-Object {
                        "'$_'"
                    }
        ) -join ', '
        # cmdletsToExport: What's the difference from functionsToExport?
        # aliasesToExport: How are you supposed to define aliases in modules?
        # variablesToExport: How are you supposed to define variables in modules?)
        $noEmptyParams = $updateParams.GetEnumerator() | Where Value
        Update-ModuleManifest @noEmptyParams -Path $moduleFile
    }
    finally {
        cd $odir
    }

}