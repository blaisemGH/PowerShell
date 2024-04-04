using namespace System.Collections.Generic

Function Join-ObjectLinq {
    Param(
        [object[]]$inputObjectLeft,
        [object[]]$inputObjectRight,
        [string]$joinColsLeft,
        [string]$joinColsRight,
        [ValidateSet('inner','left','right', 'full')]
        [string]$joinType = 'inner'
    )
    If ( $joinType -eq 'right' ) {
        $inpObjB = $inputObjectLeft
        $inpObjA = $inputObjectRight
        $joinColsB = $joinColsLeft
        $joinColsA = $joinColsRight
        $dupFieldName = 'left'
    }
    Else {
        $inpObjA = $inputObjectLeft
        $inpObjB = $inputObjectRight
        $joinColsA = $joinColsLeft
        $joinColsB = $joinColsRight
        $dupFieldName = 'right'
    }
    [hashset[string]]$colA = $inpObja | Get-Member -MemberType NoteProperty | Select -exp Name
    [hashset[string]]$colb = $inpObjb | Get-Member -MemberType NoteProperty | Select -exp Name
    [hashset[string]]$cols = $colA.clone()
    $cols.UnionWith($colb)
    
    [text.stringbuilder]$outCols = ''
    [void]$outCols.AppendLine('{Param($x,$y) [PSCustomObject]@{')

    Foreach ($col in $colA){
        If ( $col -in $cols ) {
            [void]$outCols.AppendLine("'$col' = `$x.'$col'")
        }
    }
    Foreach ($col in $colB){
        If ( $col -in $colA -and $col -notin $joinColsA ) {
            [void]$outCols.AppendLine("'${dupFieldName}_$col' = `$y.'$col'")
        }
        Elseif ($col -notin $colA) {
            [void]$outCols.AppendLine("'$col' = `$y.'$col'")
        }
    }
    [void]$outCols.AppendLine('}}')

    $sb = Invoke-Expression ($outCols.ToString())

    Switch -regex ($joinType) {
        'inner' {
            $outer = [Collections.Generic.IEnumerable[object]]$inpObja
            $inner = [Collections.Generic.IEnumerable[object]]$inpObjb
            $funcOuter = [System.Func[Object,string]] {param ($x);$x.$JoinColsA}
            $funcInner = [System.Func[Object,string]] {param ($y);$y.$JoinColsB}
            $result = (
                [System.Func[Object,Object,Object]]{
                    param ($x,$y)
                    
                    & $sb $x $y
                }
            )
            $join = 'Join'
        }
        '(left)|(right)' {
            $outer = [Collections.Generic.IEnumerable[object]]$inpObja
            $inner = [linq.Enumerable]::DefaultIfEmpty([Collections.Generic.IEnumerable[object]]$inpObjb)
            $funcOuter = [System.Func[Object,string]] {param ($x);$x.$JoinColsA}
            $funcInner = [System.Func[Object,string]] {param ($y);$y.$JoinColsB}
            $result = (
                [System.Func[Object,[Collections.Generic.IEnumerable[object]],Object]]{
                    param ($x,$y)
                    
                    & $sb $x $y
                }
            )
            $join = 'GroupJoin'
        }
        'full' {
            $outer = [Collections.Generic.IEnumerable[object]]$inpObja
            $inner = [linq.Enumerable]::DefaultIfEmpty([Collections.Generic.IEnumerable[object]]$inpObjb)
            $funcOuter = [System.Func[Object,string]] {param ($x);$x.$JoinColsA}
            $funcInner = [System.Func[Object,string]] {param ($y);$y.$JoinColsB}
            $result = (
                [System.Func[Object,[Collections.Generic.IEnumerable[object]],Object]]{
                    param ($x,$y)
                    
                    & $sb $x $y
                }
            )
            $join = 'GroupJoin'
            $fullouterJoin = Join-ObjectLinq $inputObjectLeft $inputObjectRight $joinColsLeft $joinColsRight 'right'
        }
    }

    $linq = [System.Linq.Enumerable]::$join($outer, $inner, $funcOuter, $funcInner, $result )
    return ([Linq.Enumerable]::ToArray($linq) + $fullouterJoin)
}
