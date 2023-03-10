Class PSDirTree {
    ### This class outputs 4 attributes by default. The 5 remaining are hidden so as not to clutter the output but accessible if explicitly called.
    [string]$Attributes
    [string]$LastWriteTimeView
    [string]$LengthView
    [string]$Path
    Hidden [int64]$Length
    Hidden [DateTime]$CreationTime
    Hidden [DateTime]$LastAccessTime
    Hidden [DateTime]$LastWriteTime
    Hidden [string]$DirectoryName
    Hidden [string]$FileName
    Hidden static [Hashtable]$subDirLengthMap = @{}

    ### Default constructor for the PSDirTree class
    PSDirTree(
        [System.IO.FileAttributes]$attributes,
        [DateTime]$LastWrite,
        [string]$path,
        [string]$name,
        [DateTime]$creation,
        [DateTime]$LastAccess,
        [String]$directoryName,
        [string]$parentPath,
        [string]$childPath,
        [bool]$tree,
        [bool]$noDir,
        [bool]$noLengthCalc
    ) {
        ### The attributes of PSDirTree are set here. Primarily the string format syntax is used to manage the column width in the output.
        $this.Attributes        =    '{0,-30}' -f ($attributes -Replace 'Archive' , 'File')
        $this.LastWriteTime     =    $LastWrite
        $this.LastWriteTimeView =    '{0,-10} {1,-8} {2, -6}' -f (Get-Date $LastWrite -Format 'd/M/yyyy'), (Get-Date $LastWrite -Format 'h:mm:ss'), (Get-Date $lastWrite -Format 'tt')
        If ( $noLengthCalc -or (
                $noDir -and $attributes -Contains 'Directory'
            )
        ) {
            $this.Length     = $null
        }
        Else {
            $arrLength       =  [PSDirTree]::Get_LengthView($path, $attributes)
            $this.Length     =  $arrLength[0]
            $formatLength    =  $arrLength[1]
            $unit            =  $arrLength[2].replace('0', '')
            $this.LengthView =  '{0,7} {1,2}   ' -f $formatLength, $unit
            #$this.Length    =  '{0,-15}'        -f $this.Get_LengthView($path, $attributes)
        }
        $this.Path  = & {
		    If ( $tree ) {
                '{0, -125}'  -f $this.setTree($path, $name, $parentPath, $childPath)
            }
            Else {
                '{0, -150}'  -f $childPath
            }
        }
        $this.creationTime   =  $creation
        $this.LastAccessTime =  $LastAccess
        $this.DirectoryName  =  $DirectoryName
        $this.FileName       =  $name
    }

    static [list[string]]Convert_Length ( [int64]$byteLength ) {
        If ( !$byteLength ) {
            $logLength = 0
            $convertUnit = 0
        }
        Else {
            ### This converts bytes into a power of 1024 (truncated). Based on the power, we can tell if it's Kb, Mb, Gb, etc.
            $convertUnit = [math]::Floor([math]::log($byteLength, 1024))
            ### After deriving the correct units, the raw bytes still need to be converted into the respective unit. This is what $logLength does.
            $logLength   = [Math]::Round($byteLength / [math]::Pow(1024,$convertUnit),3)
        }
        ### Output the adjusted byte length and its unit. In case of any error, a 0 is simply returned.
        Return $logLength, $(
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
        )
    }

    ### Get_LengthView passes the raw byte length to the Convert_Length method. A directory requires a sum over all the files and subfiles within the directory. A file requires simply a check on its length. This distinction is necessary because a -Recurse call on a compressed file (including, e.g., docx files) results in a bug that hangs the process for 60+ seconds (presumably it tries to search through each subfile).

    static [list[string]]Get_LengthView ( [string]$path, [string[]]$container ) {
        If ( $container -Contains 'Directory' ) {
            $propLength = & {
                $sum = 0
                Foreach ( $file in [System.IO.Directory]::GetFiles($path,'*','AllDirectories') ) {
                    If ( !([PSDirTree]::subDirLengthMap.ContainsKey($file) ) ){
                        [PSDirTree]::subDirLengthMap.Add($file, $length)
                        $sum += ([FileInfo]$file).Length
                    }
                    Else {
                        [PSDirTree]::subDirLengthMap.$file
                    }
                }
                [PSDirTree]::subDirLengthMap = @{}
                Return $sum
            }.GetNewClosure()
        }
        Else {
            $propLength = (Get-Item -LiteralPath $path).Length
        }
        $convertedLength = [PSDirTree]::Convert_Length( [int64]$propLength ) 
        Return $propLength, $convertedLength[0], $convertedLength[1]
    }

    ### This method builds up the lines in the tree column of the output. This requires three things: 1. How many nested levels is the current item? I indent each level by 4 characters, so I need to know how many levels to indent by. The next two steps tell me how to define each indent. 2. Is the file the last file in its directory? If yes, use a corner-arrow symbol; if no, use a T-junction symbol. 3. Are any of its parent directories the last item in that directory? If yes, don't draw any lines below it; if no, draw a line below it so that later files in that subdirectory are connected. This means I have to recreate the relative path of each parent subdirectory up until the root directory for each item processed. Once I have this information, I space the tree attribute according to the number of indentations, defining these indents according to the results from steps 2 and 3.
    [string]setTree ($path, $name, $parentPath, $childPath) {
        $arrDir = @()
        ### This defines step 3 mentioned in the comment above. I build the relative path of each parent directory.
        $iterateParent = $parentPath
        ForEach ( $dir in $childPath.split('\') ) {
            $iterateParent = Join-Path $iterateParent $dir
            $arrDir += $iterateParent.Trim('/\')
        }
        $output = ''
        $count  = $arrDir.count
        If ( $count -gt 1 ) { ### Tests whether this item is NOT a subitem of the root directory. Direct subitems don't need tree indentations.
            If ( $count -gt 2 ) { ### Is it nested by more than 2 layers? If yes, I need to check the parent directories (step 3 above).
                ForEach ( $index in 1..($arrDir.GetUpperBound(0) -1 ) ) { ### Testing each parent directory for whether it's the last item.
                    If ( $this.testIfLastItem($arrDir[$index]) ) {
                        $output += '    ' ### define indent as 4 spaces (parent dir is the last in its directory)
                    }
                    Else {
                        $output += [Text.Encoding]::UTF8.GetString(@('226','148','130')) + '   ' ### Define indent as a | + 3 spaces
                    }
                }
            }
            If ( $this.testIfLastItem($path) ) {
                $output += ([Text.Encoding]::UTF8.GetString(@('226','148','148','226','148','128','226','148','128')) + ' ' + $name ) ### Use a corner arrow symbol
            }
            Else {
                $output += ([Text.Encoding]::UTF8.GetString(@('226','148','156','226','148','128','226','148','128')) + ' ' + $name ) ### Use a T-junction symbol
            }
        }
        Else { ### If the item is a direct subitem of the root directory, no indentation is needed, just output its name.
            $output = $name
        }
        Return $output
    }

    ### This method returns whether a given item is the last item in its directory.
    [bool]testIfLastItem([string]$itemPath) {
        Return $(
            $itemPath -eq (
                [array](### Set as an array in case the item is the only item in its directory (PS fails the [-1] call at the end otherwise)
                    [System.IO.Directory]::GetFileSystemEntries(
                        (Split-Path $itemPath -Parent) ### Get all files in the same directory as item path
                    ) | Sort-Object
                )
            )[-1] ### Select the last item in this directory to be compared with $itemPath
        )
    }
}
Function Get-Dir {
    [OutputType([PSDirTree[]])]
    Param(
        [string]$path='*',
        [string]$filter='*',
        [int]$depth,
        [switch]$tree,
        [switch]$noRecurse,
        [switch]$noDirLength,
        [switch]$noLengthCalc
    )
    $settingFormatEnumerationLimit = $FormatEnumerationLimit
    try {
        $FormatEnumerationLimit = -1
        ### Handles asterisks and . in the input path argument, and it will also remove any .. syntax that may confuse later code.
        $cleanPath = (Convert-Path ($path -replace '[*]','.')).trim('/\')
    
        ### Output the top-level path (root of the tree)
        Write-Host ( '{0}{1}Root Search Path: {2}' -f [Environment]::NewLine, "`t", $cleanPath ) -Fore Green
    
        ### This calls the .NET method GetFileSystemEntries to grab all the directories and files. It returns these as strings, so the sort is inexpensive. On a test of 30k directories and 140k files, this method ran in 3-5 seconds, while Get-ChildItem took 3 minutes. The sort is required to establish the tree hierarchy. Also, a '/' is added at the end of each path before the sort and removed via trim after the sort. This is because a '/' is sorted before a '.', where otherwise the '.' is sorted before a '\' or newline. This ensures the arrows point to the subfiles of directory, e.g., 7-zip, instead of to a file in the same directory as 7-zip, e.g., 7-zip.dll. After the sort and trim, the output is defined as an array of FileInfo. This converts the strings into FileInfo objects.
        $recurse =  If ( $noRecurse ) {
                        'TopDirectoryOnly'
                    } Else { 'AllDirectories' }
        try {
            [System.IO.FileInfo[]]$fileList = ([System.IO.Directory]::GetFileSystemEntries( $cleanPath,$filter,$recurse) -Replace '$','/' | Sort-Object).Trim('/')
        }
        catch {
            [System.IO.FileInfo[]]$fileList = (((Get-ChildItem $cleanPath -Filter $filter -Recurse:(!$noRecurse)).FullName -Replace '$','/') | Sort-Object).Trim('/')
        }
        
        ### Loop through the list of FileInfo objects. The $childPath is the relative path to the parent. It's needed anyways for the setTree method in the PSDirTree class, so the cost of defining it earlier in this loop should be negligible. The reason it's useful here is to set up a condition for the depth argument. Since Get-ChildItem isn't being used, the depth parameter must be handled via this condition.
        ForEach ( $f in $fileList ) {
            $childPath = ($f.FullName).replace("$cleanPath",'').trim('/\')
            If ( $depth -eq $null -or (
                $depth -ge 0 -and $childPath -split '\\'
            ).Count -le ($depth + 1) 
            ) {
                ### This instantiates the PSDirTree class and simulatenously outputs it, one item (dir or file) at a time.
                [PSDirTree]::New( $f.Attributes, $f.LastWriteTime, $f.FullName, $f.Name, $f.CreationTime, $f.LastAccessTime, $f.DirectoryName, $cleanPath, $childPath,$tree, $noDirLength, $noLengthCalc )
            }
        }
    }
    catch {$_}
    finally {
        $FormatEnumerationLimit = $settingFormatEnumerationLimit
    }
}
