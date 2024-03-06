<#
    .SYNOPSIS
        This is one of my first functions and is a helper function to emulate the "find" command from Unix. It is aliased to find.
        
        In PowerShell terms, it is like a Get-ChildItem with auto recurse, the possibility to specify a max depth on recursion, and a delete option built in.
#>
Function Find-FileRecursively {

    [CmdletBinding(DefaultParameterSetName='PathAndFile')]
    Param (
        [Parameter(Mandatory, ValueFromPipeline, Position=0)]
        [Alias('PSPath')]
        [string]$Path,

        [Alias('regExFilter')]
        [Parameter(Position=1)]
        [string]$Name = '.*',

        [Parameter()]
        [alias('depth','d')]
        [int]$MaxDepth,

        [string]$Filter,

        [alias('nr')]
        [switch]$NoRecurse,

        [Parameter(ParameterSetName = 'PathAndFile')]
        [switch]$File,

        [Parameter(ParameterSetName = 'PathAndDirectory')]
        [switch]$Directory,

        [switch]$SortOutput,

        [switch]$Delete,

        [Alias('fast')]
        [switch]$dotNet
    )
    begin {
        $GCIParams = @{}
        
        If ( $NoRecurse ) {
            $Recurse = 'TopDirectoryOnly'
        }
        Else {
            $gciRecurse = $True
            $Recurse = 'AllDirectories'
        }

        If ( $MaxDepth ) {
            $GCIParams.Depth = $MaxDepth - 1
        }
        $GCIParams.Recurse = $gciRecurse
        $GCIParams.Filter = $Filter
        $GCIParams.File = $File
        $GCIParams.Directory = $Directory
    }
    process {
        $cleanPath = Convert-Path -LiteralPath $Path
        
        If ( !$dotNet ) {
            $Name = $Name -replace '([^.])[*]','$1.*' -replace '^[*]','.*'
            $fileList = (Get-ChildItem -LiteralPath $cleanPath @GCIParams).Where({$_.Name -match "^${Name}$"}) 
        }
        Else {
            If ( $Filter ) {
                $Name = $Filter
            }
            $Name = $Name -replace '[.][*]','*' 
            if ( $Name -match '[?+\[\]\(\)^$\{\}]' ) { Write-Warning 'The dotnet (fast) switch does not support RegEx!'; ''}
            if ( $File ) {
                [System.IO.FileInfo[]]$fileList = [System.IO.Directory]::GetFiles( $cleanPath,$Name,$Recurse)
            }
            elseIf ( $Directory ) {
                [System.IO.DirectoryInfo[]]$fileList = [System.IO.Directory]::GetDirectories( $cleanPath,$Name,$Recurse)
            }
            else {
                $fileList = [System.IO.Directory]::EnumerateFileSystemEntries( $cleanPath,$Name,$Recurse)
            }
        }
    }
    end {
        If ( $SortOutput ) {
            $fileList | Resolve-Path -Relative | Sort-Object
        }
        Else {
            $fileList | Resolve-Path -Relative
        }

        If ( $fileList -and $Delete ) {
            $msg = 'You have activated the -delete switch. Do you really wish to delete the above files? [yes/no]'
            $validation = @('yes','no')
            $prompt = Test-ReadHost -Query $msg -ValidationStrings $validation
            If ( $prompt -eq 'yes' ) { $fileList | Remove-Item -Force }
        }
    }
}
