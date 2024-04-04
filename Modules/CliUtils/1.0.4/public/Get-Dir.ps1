using namespace System.IO
<#
    .SYNOPSIS
        An alternative to Get-ChildItem which leverages a formatted output and the option to display your file structure in a tree format.
            * Use the -Tree parameter to produce a tree output.
            * Filter input with standard wildcard patterns.
            * By default runs recursively. Use the parameters Depth to limit it or NoRecurse to deactivate this.
            * By default calculates the size of directories and formats these into the nearest units. Deactivate this (faster) with NoDirSize.
            * By default calculates the formats the length of files into the nearest units. Deactivate this (faster) with NoCalcSize.
#>
Function Get-Dir {
    [OutputType([PSDirTree[]])]
    Param(
        [Alias('PSPath')]
        [string]$Path='*',
        [string]$Filter='*',
        [int]$Depth,
        [switch]$Tree,
        [switch]$NoRecurse,
        [switch]$NoDirSize,
        [switch]$NoCalcSize,
        [switch]$Force
    )
    $settingFormatEnumerationLimit = $FormatEnumerationLimit
    try {
        $FormatEnumerationLimit = -1
        ### Handles asterisks and . in the input path argument, and it will also remove any .. syntax that may confuse later code.
        $rootPath    =    (Convert-Path ($Path -replace '[*]','.')).trim('/\')
        $parentPath = Split-Path $rootPath -Parent
    
        ### Output the top-level path (root of the tree)
        Write-Host ( '{0}{1}Root Search Path: {2}' -f [Env]::NL, "`t", $rootPath ) -Fore Green
    
        ### This calls the .NET method GetFileSystemEntries to grab all the directories and files. It returns these as strings, so the sort is inexpensive. On a test of 30k directories and 140k files, this method ran in 3-5 seconds, while Get-ChildItem took 3 minutes. The sort is required to establish the tree hierarchy. Also, a '/' is added at the end of each path before the sort and removed via trim after the sort. This is because a '/' is sorted before a '.', where otherwise the '.' is sorted before a '\' or newline. This ensures the arrows point to the subfiles of directory, e.g., 7-zip, instead of to a file in the same directory as 7-zip, e.g., 7-zip.dll. After the sort and trim, the output is defined as an array of FileInfo. This converts the strings into FileInfo objects which populates the various file attributes that are enriched in the output.
        $recurse    =    If ( $NoRecurse ) {
                            'TopDirectoryOnly'
                        } Else { 'AllDirectories' }
        try {
            [FileInfo[]]$fileList = ([Directory]::GetFileSystemEntries( $rootPath,$Filter,$recurse) -Replace [PSDirTree]::appendCharacter,'/' | Sort-Object).Trim('/')
        }
        catch {
            [FileInfo[]]$fileList = (((Get-ChildItem $rootPath -Filter $Filter -Recurse:(!$NoRecurse) -Force:$Force -Name) -Replace [PSDirTree]::appendCharacter ,'/') | Sort-Object).Trim('/')
        }
        
        ### Loop through the list of FileInfo objects. The $childPath is the relative path to the parent. It's needed anyways for the setTree method in the PSDirTree class, so the cost of defining it earlier in this loop should be negligible. The reason it's useful here is to set up a condition for the depth argument. Since Get-ChildItem isn't being used, the depth parameter must be handled via this condition.
        ForEach ( $f in $fileList ) {
            $childPath = ($f.FullName).replace($rootPath,'').trim([Path]::DirectorySeparatorChar)
            If ( $Depth -eq $null -or (
                        $Depth -ge 0 -and $childPath.Split([Path]::DirectorySeparatorChar)
                    ).Count -le ($Depth + 1) 
            ) {
                ### This instantiates the PSDirTree class and simulatenously outputs it, one item (dir or file) at a time.
                [PSDirTree]::new( $f.Attributes, $f.LastWriteTime, $f.FullName, $f.Name, $f.CreationTime, $f.LastAccessTime, $f.DirectoryName, $rootPath, $childPath, $Tree, $NoDirSize, $NoCalcSize )
            }
        }
    }
    catch {$_}
    finally {
        $FormatEnumerationLimit = $settingFormatEnumerationLimit
    }
}
