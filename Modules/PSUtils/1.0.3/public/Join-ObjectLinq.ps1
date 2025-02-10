using namespace System.Collections.Generic

Function Join-ObjectLinq {
    Param(
        [Parameter(Mandatory)]
        [object[]]$LeftInputObject,

        [Parameter(Mandatory)]
        [object[]]$RightInputObject,

        [Parameter(Mandatory)]
        [string[]]$LeftJoinKeys,

        [Parameter(Mandatory)]
        [string[]]$RightJoinKeys,

        [ValidateSet('inner','left','right', 'full')]
        [string]$JoinType = 'inner'
    )

    If ( $JoinType -eq 'right' ) {
        $inpObjB = $LeftInputObject
        $inpObjA = $RightInputObject
        $joinColsB = $LeftJoinKeys
        $joinColsA = $RightJoinKeys
        $dupFieldName = 'left'
    }
    Else {
        $inpObjA = $LeftInputObject
        $inpObjB = $RightInputObject
        $joinColsA = $LeftJoinKeys
        $joinColsB = $RightJoinKeys
        $dupFieldName = 'right'
    }

    [hashset[string]]$colA = $inpObja | Get-Member -MemberType Properties | Select-Object -exp Name
    [hashset[string]]$colB = $inpObjb | Get-Member -MemberType Properties | Select-Object -exp Name

    if ( !$colA ) {
        $errMsg = "No property names found in left object to join"
        $err = New-ErrorRecord -ExceptionText $errMsg -ErrorId 'MissingColumns' -ErrorCategory InvalidData
        $PSCmdlet.ThrowTerminatingError($err)
    }
    if ( !$colB ) {
        $errMsg = "No property names found in right object to join"
        $err = New-ErrorRecord -ExceptionText $errMsg -ErrorId 'MissingColumns' -ErrorCategory InvalidData
        $PSCmdlet.ThrowTerminatingError($err)
    }

    [hashset[string]]$cols = $colA.Clone()
    $cols.UnionWith($colB)
    
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
            $outer = [IEnumerable[object]]$inpObja
            $inner = [IEnumerable[object]]$inpObjb
            $funcOuter = [Func[Object,string]] {param ($x); foreach ($colA in $JoinColsA) { $x.$colA}}
            $funcInner = [Func[Object,string]] {param ($y); foreach ($colB in $JoinColsB) { $y.$colB}}
            $result = (
                [Func[Object,Object,Object]]{
                    param ($x,$y)
                    
                    & $sb $x $y
                }
            )
            $join = 'Join'
        }
        '(left)|(right)' {
            $outer = [IEnumerable[object]]$inpObja
            $inner = [Linq.Enumerable]::DefaultIfEmpty([IEnumerable[object]]$inpObjb)
            $funcOuter = [Func[Object,string]] {param ($x); foreach ($colA in $JoinColsA) { $x.$colA}}
            $funcInner = [Func[Object,string]] {param ($y); foreach ($colB in $JoinColsB) { $y.$colB}}
            $result = (
                [Func[Object,[IEnumerable[object]],Object]]{
                    param ($x,$y)
                    
                    & $sb $x $y
                }
            )
            $join = 'GroupJoin'
        }
        'full' {
            $outer = [IEnumerable[object]]$inpObja
            $inner = [Linq.Enumerable]::DefaultIfEmpty([IEnumerable[object]]$inpObjb)
            $funcOuter = [Func[Object,string]] {param ($x); foreach ($colA in $JoinColsA) { $x.$colA}}
            $funcInner = [Func[Object,string]] {param ($y); foreach ($colB in $JoinColsB) { $y.$colB}}
            $result = (
                [Func[Object,[IEnumerable[object]],Object]]{
                    param ($x,$y)
                    
                    & $sb $x $y
                }
            )
            $join = 'GroupJoin'
            $fullouterJoin = Join-ObjectLinq $LeftInputObject $RightInputObject $LeftJoinKeys $RightJoinKeys 'right'
        }
    }

    $linq = [Linq.Enumerable]::$join($outer, $inner, $funcOuter, $funcInner, $result )

    if ( $fullouterjoin ) {
        return ([Linq.Enumerable]::ToArray($linq) + $fullouterJoin)
    }
    return ([Linq.Enumerable]::ToArray($linq))
}
