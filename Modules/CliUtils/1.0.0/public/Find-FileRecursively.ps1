<#
    .SYNOPSIS
        This is one of my first functions and is a helper function to emulate the "find" command from Unix. It is aliased to find.
        
        In PowerShell terms, it is like a Get-ChildItem with auto recurse, the possibility to specify a max depth on recursion, and a delete option built in.
#>
Function Find-FileRecursively {

    [CmdletBinding(DefaultParameterSetName='Default')]
    Param (
        [Parameter(Mandatory,Position=0,ParameterSetName = 'Default')]
        [Parameter(Mandatory,Position=0,ParameterSetName = 'PathAndFile')]
        [Parameter(Mandatory,Position=0,ParameterSetName = 'PathAndDirectory')]
        $Path,

        [Alias('regExFilter')]
        [Parameter(Position=1)]
        $Name = '.*',

        [Parameter(Mandatory,ParameterSetName = 'Literal')]
        [Parameter(Mandatory,ParameterSetName = 'LitPathAndFile')]
        [Parameter(Mandatory,ParameterSetName = 'LitPathAndDirectory')]
        $LiteralPath,

        [Parameter()]
        [alias('depth','d')]
        [int]$MaxDepth,

        [string]$Filter,

        [alias('nr')]
        [switch]$NoRecurse,

        [Parameter(Mandatory=$true,ParameterSetName = 'PathAndFile')]
        [Parameter(Mandatory=$true,ParameterSetName = 'LitPathAndFile')]
        [switch]$File,

        [Parameter(Mandatory=$true,ParameterSetName = 'PathAndDirectory')]
        [Parameter(Mandatory=$true,ParameterSetName = 'LitPathAndDirectory')]
        [switch]$Directory,

        [Parameter(ParameterSetName = 'PathAndFile')]
        [Parameter(ParameterSetName = 'LitPathAndFile')]
        [FileProperties]$SortFiles,

        [Parameter(ParameterSetName = 'PathAndDirectory')]
        [Parameter(ParameterSetName = 'LitPathAndDirectory')]
        [DirectoryProperties]$SortDirs,

        [switch]$Delete,

        [Alias('fast')]
        [switch]$dotNet
    )

    $params = $PSBoundParameters
    
    If ( $params.ContainsKey('LiteralPath') ) {
        $cleanPath = $LiteralPath
        $cdir = (PWD).Path -replace '\\','\\'
    }
    Else {
        $cleanPath = Convert-Path $Path
        $params.'Path' = $cleanPath
        $cdir = $cleanPath -replace '\\','\\' #$Path -replace '^[/\\]?([.][.][/\\])+','.\' -replace '\\','\\'
    }
    
    If ( $NoRecurse ) {
        $params.Remove('NoRecurse')
        $Recurse = 'TopDirectoryOnly'
    }
    Else {
        $params.Add( 'Recurse' , $True )
        $Recurse = 'AllDirectories'
    }
    
    If ( $MaxDepth ) {
        $params.Add( 'Depth' , $MaxDepth - 1)
        $params.Remove('MaxDepth')
    }

    [void]$params.Remove(    'Name'            )
    [void]$params.Remove(    'Delete'        )
    [void]$params.Remove(    'SortFiles'        )
    [void]$params.Remove(    'SortDirs'        )

    [String]$Sort = If        ( $SortFiles ) { $SortFiles }
                    ElseIf    ( $SortDirs     ) { $SortDirs  }
    
    Write-Host ""
    
    If ( Test-Path $cleanPath ) {
        
        If ( !$dotNet ) {
            $Name = $Name -replace '([^.])[*]','$1.*' -replace '^[*]','.*'
            $fileList = Get-ChildItem @params | Where Name -match "^${Name}$" | Sort-Object $Sort | Select-Object -ExpandProperty FullName
        }
        Else {
            If ( $Filter ) {
                $Name = $Filter
            }
            $Name = $Name -replace '[.][*]','*' 
            If ( $Name -match '[?+\[\]\(\)^$\{\}]' ) { Write-Warning 'The fast switch does not support RegEx!'; ''}
            If ( $File ) {
                [System.IO.FileInfo[]]$fileList = [System.IO.Directory]::GetFiles( $cleanPath,$Name,$Recurse)
            }
            ElseIf ( $Directory ) {
                [System.IO.DirectoryInfo[]]$fileList = [System.IO.Directory]::GetDirectories( $cleanPath,$Name,$Recurse)
            }
            Else {
                [System.IO.FileInfo[]]$fileList = [System.IO.Directory]::GetFileSystemEntries( $cleanPath,$Name,$Recurse)
            }
        }
    }
    Else {
        Throw "$cleanPath does not exist!"
    }

    If ($fileList) {
        If ( $File -or $Directory ) {
            ($fileList | Sort-Object $Sort) -Replace $cdir, '.\' | Select-Object -last 100
        }
        Else {
            $fileList -Replace $cdir, '.\' | Select-Object -last 100
        }
        If ($fileList.Count -gt 100 ) {
            Write-Host ('{0}...and {1} more files{2}' -f [Env]::NL, ( $fileList.Count - 100 ) , [Env]::NL )
        }
    }

    If ( $fileList -and $Delete ) {
        $msg = 'You have activated the -delete switch. Do you really wish to delete the above files? [yes/no]'
        $validation = @('yes','no')
        $prompt = Test-ReadHost -Query $msg -ValidationStrings $validation
        If ( $prompt -eq 'yes' ) { $fileList | Remove-Item -Force }
    }
}
