<#
    .DESCRIPTION
        This is one of my first functions and is a helper function to emulate the "find" command from Unix.
        I originally included -Delete and sorting options and considered -exec, but ultimately it was making
        the function worse to force in the Linux find syntax when PS performs these tasks differently.
        
        In PowerShell terms, it is like a Get-ChildItem with auto recurse, but it uses .NET by default to be faster.
        You may also think of it as a wrapper to access the faster .NET search using familiar Get-ChildItem params,
        which are mapped to the EnumerationOptions of the .NET method.

        On Windows, it is aliased to find.

#>
function Find-FileRecursively {
    [CmdletBinding(DefaultParameterSetName='default')]
    Param (
        [Parameter(Mandatory, ValueFromPipeline, Position=0)]
        [Alias('PSPath')]
        [string]$Path,

        [Parameter(Position=1)]
        [Alias('name')]
        [string]$Filter = '*',

        [Parameter(ParameterSetName = 'LinuxFindType')]
        [ValidateSet('d','f')]
        [string]$Type,

        [alias('depth','d')]
        [ValidatePattern(1)]
        [int]$MaxDepth,

        [alias('nr')]
        [switch]$NoRecurse,

        [alias('f')]
        [switch]$Force,

        [alias('cs')]
        [switch]$CaseSensitive,

        [Parameter(ParameterSetName = 'File')]
        [switch]$File,

        [Parameter(ParameterSetName = 'Directory')]
        [switch]$Directory
    )
    begin {
        $GCIParams = @{}
        $enumerationOptions = [System.IO.EnumerationOptions]::new()
        if ( ! $NoRecurse ) {
            $gciRecurse = $true
            $enumerationOptions.RecurseSubdirectories = $true
        }

        if ( $MaxDepth ) {
            $GCIParams.Depth = $MaxDepth
            $enumerationOptions.MaxRecursionDepth = $MaxDepth
        }

        if ( ! $Force ) {
            $enumerationOptions.AttributesToSkip = @('Hidden', 'System')
        }
        if ( $CaseSensitive ) {
            $enumerationOptions.MatchCasing = 'CaseSensitive'
            $likeOperator = {$_ -clike $Name }
        } else {
            $enumerationOptions.MatchCasing = 'CaseInsensitive'
            $likeOperator = {$_ -like $Name }
        }

        $GCIParams.Recurse = $gciRecurse
        $GCIParams.Filter = $Filter
        $GCIParams.Force = $Force

        if ( $Directory -or $Type -eq 'd' ) {
            $GCIParams.Directory = $Directory
            $FileSystemType = 'directory'
        }
        elseif ( $File -or $Type -eq 'f' ) {
            $GCIParams.File = $File
            $FileSystemType = 'file'
        }
    }
    process {
        $cleanPath = Convert-Path -LiteralPath $Path -ErrorAction Stop

        try {
            switch ($FileSystemType) {
                'directory' {[System.IO.Directory]::EnumerateDirectories( $cleanPath, $Filter, $enumerationOptions) | Resolve-Path -Relative }
                'file' {[System.IO.Directory]::EnumerateFiles( $cleanPath, $Filter, $enumerationOptions) | Resolve-Path -Relative }
                DEFAULT {
                    [System.IO.Directory]::EnumerateFileSystemEntries( $cleanPath, $Filter, $enumerationOptions) | Resolve-Path -Relative
                }
            }
        } catch [UnauthorizedAccessException] {
            Get-ChildItem -LiteralPath $cleanPath @GCIParams -Name | Where-Object $likeOperator
        }
    }
}
