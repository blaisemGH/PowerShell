using namespace System.IO
using namespace System.Collections.Generic
using namespace System.Text

Class PSDirTree {
    ### This class outputs 4 attributes by default. The 5 remaining are hidden so as not to clutter the output but accessible if explicitly called.
    [string]$Attributes
    [string]$Size
    [string]$SubPath
    [int64]$Length
    [DateTime]$CreationTime
    [DateTime]$LastAccessTime
    [DateTime]$LastWriteTime
    [string]$ParentDirPath
    [string]$Name
    [string]$RootSearchPath
    [string]$Path
    Hidden static [Hashtable]$subDirSizeMap = @{}
    Hidden static [Regex]$appendCharacter = [Regex]::new('$','Compiled')
    Hidden static [string]$CornerArrow = [Encoding]::UTF8.GetString(@('226','148','148','226','148','128','226','148','128'))
    Hidden static [string]$TJunction = [Encoding]::UTF8.GetString(@('226','148','156','226','148','128','226','148','128'))
    Hidden static [string]$VerticalBar = [Encoding]::UTF8.GetString(@('226','148','130'))

    ### Default constructor for the PSDirTree class
    PSDirTree(
        [FileAttributes]$attributes,
        [DateTime]$LastWriteTime,
        [string]$path,
        [string]$name,
        [DateTime]$creation,
        [DateTime]$LastAccess,
        [String]$parentDirPath,
        [string]$rootPath,
        [string]$childPath,
        [bool]$tree,
        [bool]$noDir,
        [bool]$noCalcSize
    ) {
        $this.Attributes    =    $attributes -Replace 'Archive','File'
        $this.LastWriteTime =    $LastWriteTime
        If ( $noCalcSize -or (
                $noDir -and $attributes -Contains 'Directory'
            )
        ) {
            $this.Length  = $null
        }
        Else {
            $arrSize      =    [PSDirTree]::GetSize($path, $attributes)
            $this.Length  =    $arrSize[0]
            $rawLength    =    $arrSize[1]
            $unit         =    $arrSize[2].replace('0','')
            $this.Size    =    '{0,7} {1,2}   '    -f $rawLength, $unit
        }
        $this.SubPath = & {
            If ( $tree ) {
                $this.setTree($path, $name, $rootPath, $childPath)
            }
            Else {
                $childPath
            }
        }
        $this.creationTime   = $creation
        $this.LastAccessTime = $LastAccess
        $this.RootSearchPath = $rootPath
        $this.ParentDirPath  = $parentDirPath
        $this.Name = $name
        $this.Path = Join-Path $rootPath $childPath
    }

    static [list[string]]ConvertSize ( [int64]$byteSize ) {
        If ( !$byteSize ) {
            $logSize = 0
            $convertUnit = 0
        }
        Else {
            ### This converts bytes into a power of 1024 (truncated). Based on the power, we can tell if it's Kb, Mb, Gb, etc.
            $convertUnit = [math]::Floor([math]::log($byteSize,  1024))
            ### After deriving the correct units, the raw bytes still need to be converted into the respective unit. This is what $logSize does.
            $logSize     = [Math]::Round($byteSize / [math]::Pow(1024,$convertUnit),3)
        }
        ### Output the adjusted byte size and its unit. In case of any error, a 0 is simply returned.
        Return $logSize, ( & { 
            Switch ( $convertUnit ) {
                0 { " b" }
                1 { "Kb" }
                2 { "Mb" }
                3 { "Gb" }
                4 { "Tb" }
                5 { "Pb" }
                6 { "Eb" }
                7 { "Zb" }
                8 { "Yb" }
                Default { '' }
            }
        })
    }

    ### getSize passes the raw byte size to the convertSize method. A directory requires a sum over all the files and subfiles within the directory. A file requires simply a check on its length. This distinction is necessary because a -Recurse call on a compressed file (including, e.g., docx files) results in a bug that hangs the process for 60+ seconds (presumably it tries to search through each subfile).

    static [list[string]]GetSize ( [string]$path, [string[]]$container ) {
        $rawLength = & {
            If ( $container -Contains 'Directory' ) {
                $sum = 0
                Foreach ( $file in [System.IO.Directory]::GetFiles($path,'*','AllDirectories') ) {
                    $fileLength = ([FileInfo]$file).Length
                    If ( !([PSDirTree]::subDirSizeMap.ContainsKey($file) ) ){
                        [PSDirTree]::subDirSizeMap.Add($file, $fileLength)
                        $sum += $fileLength
                    }
                    Else {
                        [PSDirTree]::subDirSizeMap.$file
                    }
                }
                [PSDirTree]::subDirSizeMap = @{}
                Return $sum
            }
            Else {
                (Get-Item -LiteralPath $path).Length
            }
        }.GetNewClosure()
        $convertedLength = [PSDirTree]::convertSize( [int64]$rawLength ) 
        Return $rawLength, $convertedLength[0], $convertedLength[1]
    }

    ### This method builds up the lines in the tree column of the output. This requires three things: 1. How many nested levels is the current item? I indent each level by 4 characters, so I need to know how many levels to indent by. The next two steps tell me how to define each indent. 2. Is the file the last file in its directory? If yes, use a corner-arrow symbol; if no, use a T-junction symbol. 3. Are any of its parent directories the last item in that directory? If yes, don't draw any lines below it; if no, draw a line below it so that later files in that subdirectory are connected. This means I have to recreate the relative path of each parent subdirectory up until the root directory for each item processed. Once I have this information, I space the tree attribute according to the number of indentations, defining these indents according to the results from steps 2 and 3.
    [string]setTree ($path, $name, $rootPath, $childPath) {
        $arrDir = [List[string]]::new()
        
        ### This defines step 3 mentioned in the comment above. I build the relative path of each parent directory.
        $buildNestedParentDirs = $rootPath
        ForEach ( $dir in $childPath.split([Path]::DirectorySeparatorChar) ) {
            $buildNestedParentDirs = Join-Path $buildNestedParentDirs $dir
            $arrDir.Add( $buildNestedParentDirs.Trim([Path]::DirectorySeparatorChar) )
        }
        $count = $arrDir.count
        if ( $count -le 1 -or !$count ) {
            ### If the item is a direct subitem of the root directory, no indentation is needed, just output its name.
            return $name
        }
        ### Tests whether this item is NOT a subitem of the root directory. Direct subitems don't need tree indentations.
        $output = [StringBuilder]::new('')
        If ( $count -gt 2 ) {
            ### Is it nested by more than 2 layers? If yes, I need to check the parent directories (step 3 above).
            ForEach ( $index in 1..($arrDir.Count - 2 ) ) { 
                ### Testing each parent directory for whether it's the last item.
                If ( $this.testIfLastItemInDir($arrDir[$index]) ) {
                    $output.Append('    ') ### define indent as 4 spaces (parent dir is the last in its directory)
                }
                Else {
                    $output.Append( [PSDirTree]::VerticalBar + '   ') ### Define indent as a | + 3 spaces
                }
            }
        }

        If ( $this.TestIfLastItemInDir($path) ) {
            $output.Append( [PSDirTree]::CornerArrow + ' ' + $name ) ### Use a corner arrowsymbol
        }
        Else {
            $output.Append( [PSDirTree]::TJunction + ' ' + $name ) ### Use a T-junction symbol
        }
        return $output.ToString()
    }

    [bool]TestIfLastItemInDir([string]$itemPath) {
        $parentPath = Split-Path $itemPath -Parent
        ### Set as an array in case the item is the only item in its directory (PS fails the [-1] call at the end otherwise)
        Return $(
            $itemPath -eq @(
                ### Get all files in the same directory as item path
                (
                    ([Directory]::GetFileSystemEntries( $parentPath )) -replace [PSDirTree]::appendCharacter, '/' | Sort-Object
                ).Trim('/')
            )[-1]
        )
    }
}
