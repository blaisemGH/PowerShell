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
    Param (
        [Parameter(Mandatory, ValueFromPipeline, Position=0)]
        [Alias('PSPath')]
        [string]$Path,

        [alias('depth','d')]
        [ValidatePattern(1)]
        [int]$MaxDepth,

        [Alias('name')]
        [string]$Filter,

        [alias('nr')]
        [switch]$NoRecurse,

        [alias('f')]
        [switch]$Force,

        [alias('cs')]
        [switch]$CaseSensitive,

        [Parameter(ParameterSetName = 'File')]
        [switch]$File,

        [Parameter(ParameterSetName = 'Directory')]
        [switch]$Directory,

        [Parameter(ParameterSetName = 'LinuxFindType')]
        [ValidateSet('d','f')]
        [char]$Type,

        # Fall back to Get-ChildItem instead of using the faster .NET EnumerateFileSystemEntries.
        # Left in here for Windows PS users who wouldn't have the .NET workaround for AccessDenied.
        [switch]$useGCI
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
            $likeOperator = {$_.Name -clike $Name }
        } else {
            $enumerationOptions.MatchCasing = 'CaseInsensitive'
            $likeOperator = {$_.Name -like $Name }
        }

        $GCIParams.Recurse = $gciRecurse
        $GCIParams.Filter = $Filter
        $GCIParams.Force = $Force
        
        if ( $Directory -or $Type -eq 'd' ) {
            $GCIParams.Directory = $Directory
            $FileSystemType = 'file'
        }
        elseif ( $File -or $Type -eq 'f' ) {
            $GCIParams.File = $File
            $FileSystemType = 'directory'
        }
    }
    process {
        $cleanPath = Convert-Path -LiteralPath $Path

        if ( $useGCI ) {
            <#
            The Where-Object is to allow the CaseSensitive argument to work with GCI.
            Even though it's already been filtered left, the case sensitivity wouldn't have been applied.
            I'm aware this is slower in 99.99% of cases where you don't use $CaseSensitive, but otherwise there's no
            reason to use this function over GCI, so either use GCI instead in that case or don't call this with $useGCI.
            #>
          Get-ChildItem -LiteralPath $cleanPath @GCIParams | Where-Object $likeOperator
        }
        else {
            switch ($FileSystemType) {
                'directory' {[System.IO.Directory]::EnumerateDirectories( $cleanPath,$Filter,$enumerationOptions)}
                'file' {[System.IO.Directory]::EnumerateFiles( $cleanPath,$Filter,$enumerationOptions)}
                DEFAULT {
                    [System.IO.Directory]::EnumerateFileSystemEntries( $cleanPath,$Filter,$enumerationOptions)
                }
        }
    }
}
