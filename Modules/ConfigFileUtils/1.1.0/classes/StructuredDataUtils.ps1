using namespace System.Collections.Generic
using namespace System.Collections
using namespace System.IO

class StructuredDataUtils {
    [bool]$AsHashtable

    StructuredDataUtils([bool]$asHashtable) {
        $this.AsHashtable = $asHashtable
    }

    [object] ConvertFromGenericDictionary($inputObject) {
        $converter = if ( $this.asHashtable ) {
            [ConvertFromGenericDictionaryToHashtable]::new()
        } else {
            [ConvertFromGenericDictionaryToPsObject]::new()
        }

        return $converter.Convert($inputObject)
    }

    [object] ConvertToGenericDictionary($inputObject) {
        $converter = [ConvertToGenericDictionary]::new()
        if ( $inputObject -is [IList] -and $inputObject.Count -eq 1 ) {
            return $converter.Convert($inputObject[0])
        }
        return $converter.Convert($inputObject)
    }

}

class ConvertFromGenericDictionaryToHashtable {
    [hashtable] Convert ([IDictionary]$dictionary) {
        $obj = [hashtable]$dictionary
        Foreach ($entry in $dictionary.GetEnumerator()) {
            $obj.($entry.Key) = $this.Convert($entry.Value)
        }
        return $obj
    }

    [hashtable] Convert ([KeyValuePair[object, object]]$dictionary) {
        $obj = [hashtable]$dictionary
        Foreach ($entry in $dictionary.GetEnumerator()) {
            $obj.($entry.Key) = $this.Convert($entry.Value)
        }
        return $obj
    }

    [object[]] Convert ([IList]$collection) {
        return $(
            Foreach ($item in $collection) {
                $this.Convert($item)
            }
        )
    }

    [object] Convert ([object]$item) {
        return $item
    }
}

class ConvertFromGenericDictionaryToPsObject {
    [pscustomobject] Convert ([IDictionary]$dictionary) {
        $obj = [PSCustomObject][hashtable]$dictionary
        Foreach ($entry in $dictionary.GetEnumerator()) {
            $obj.($entry.Key) = $this.Convert($entry.Value)
        }
        return $obj
    }

    [pscustomobject] Convert ([KeyValuePair[object, object]]$dictionary) {
        $obj = [PSCustomObject][hashtable]$dictionary
        Foreach ($entry in $dictionary.GetEnumerator()) {
            $obj.($entry.Key) = $this.Convert($entry.Value)
        }
        return $obj
    }

    [object[]] Convert ([IList]$collection) {
        return $(
            Foreach ($item in $collection) {
                $this.Convert($item)
            }
        )
    }

    [object] Convert ([object]$item) {
        return $item
    }
}

class ConvertToGenericDictionary {
    [object] Convert ([string]$inputObject) {
        return $inputObject
    }
    [object] Convert ([type]$inputObject) {
        return $inputObject
    }

    [Dictionary[object, object]] Convert ([IDictionary]$inputObject) {
        $dictionary = [Dictionary[object,object]]::new()
        foreach ($key in ($inputObject.Keys | Sort-Object)) {
            $dictionary.Add($key, $this.Convert($inputObject[$key]))
        }
        return $dictionary
    }

    [Dictionary[object, object]] Convert ([Hashtable]$inputObject) {
        $dictionary = [Dictionary[object,object]]::new()
        foreach ($key in ($inputObject.Keys | Sort-Object)) {
            $dictionary.Add($key, $this.Convert($inputObject[$key]))
        }
        return $dictionary
    }

    [Object[]] Convert ([IList]$inputObject) {
        $collection = [List[object]]::new()
        if ( $inputObject -is [IList] ) {
            foreach ($item in $inputObject) {
                $collection.Add($this.Convert($item))
            }
        }
        return $collection
    }
    [Object[]] Convert ([ArrayList]$inputObject) {
        $collection = [List[object]]::new()
        if ( $inputObject -is [IList] ) {
            foreach ($item in $inputObject) {
                $collection.Add($this.Convert($item))
            }
        }
        return $collection
    }

    [Dictionary[object, object]] Convert ([pscustomobject]$inputObject) {
        $dictionary = [Dictionary[object,object]]::new()
        foreach ($property in ($inputObject.psobject.properties.Name | Sort-Object)) {
            $dictionary.Add($property, $this.Convert($inputObject.$property))
        }
        return $dictionary
    }

    [object] Convert ([object]$inputObject) {
        return $inputObject
    }
}