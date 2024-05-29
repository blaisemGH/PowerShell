using namespace System.Collections.Generic
using namespace System.Collections
using namespace System.IO

class StructuredDataUtils {

    static [pscustomobject] ConvertFromGenericDictionary ([IDictionary]$dictionary) {
        $obj = [PSCustomObject][hashtable]$dictionary
        Foreach ($entry in $dictionary.GetEnumerator()) {
            $obj.($entry.Key) = [StructuredDataUtils]::ConvertFromGenericDictionary($entry.Value)
        }
        return $obj
    }

    static [pscustomobject] ConvertFromGenericDictionary ([KeyValuePair[object, object]]$dictionary) {
        $obj = [PSCustomObject][hashtable]$dictionary
        Foreach ($entry in $dictionary.GetEnumerator()) {
            $obj.($entry.Key) = [StructuredDataUtils]::ConvertFromGenericDictionary($entry.Value)
        }
        return $obj
    }

    static [object[]] ConvertFromGenericDictionary ([IList]$collection) {
        return $(
            Foreach ($item in $collection) {
                [StructuredDataUtils]::ConvertFromGenericDictionary($item)
            }
        )
    }

    static [object] ConvertFromGenericDictionary ([object]$item) {
        return $item
    }


    static [Dictionary[object, object]] ConvertToGenericDictionary ([pscustomobject]$inputObject) {
        $dictionary = [Dictionary[object,object]]::new()
        foreach ($property in $inputObject.psobject.properties.Name) {
            $dictionary.Add($property, [StructuredDataUtils]::ConvertToGenericDictionary($inputObject.$property))
        }
        return $dictionary
    }
    static [Dictionary[object, object]] ConvertToGenericDictionary ([IDictionary]$inputObject) {
        $dictionary = [Dictionary[object,object]]::new()
        foreach ($key in $inputObject.Keys) {
            $dictionary.Add($key, [StructuredDataUtils]::ConvertToGenericDictionary($inputObject[$key]))
        }
        return $dictionary
    }

    static [Object[]] ConvertToGenericDictionary ([IList]$inputObject) {
        $collection = [List[object]]::new()
        if ( $inputObject -is [IList] ) {
            foreach ($item in $inputObject) {
                $collection.Add([StructuredDataUtils]::ConvertToGenericDictionary($item))
            }
        }
        return $collection
    }

    static [object] ConvertToGenericDictionary ([object]$inputObject) {
        return $inputObject
    }
}
