### Source: https://powershell.one/tricks/performance/group-object
Function Group-ObjectFixed {
    param (
        [string[]]
        $PKs
    )

	begin {
		$hashtable = @{}
	}

	process {
		# create a key based on the submitted properties, and turn it into a string
		$field = $(foreach($PK in $PKs) { $_.$PK }) -join ', '
	
		If ( -Not $hashtable.ContainsKey($field) ) {
			$hashtable["$field"] = [Collections.Arraylist]@()
		}
		$null = $hashtable["$field"].Add($_)
	}

	end {
		ForEach ($field in $hashtable.Keys) {
			[PSCustomObject] @{
				Count = $hashtable[$field].Count
				Name = $field
				Group = $hashtable[$field]
			}
		}
	}
}
