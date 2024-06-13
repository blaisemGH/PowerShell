using namespace System.Collections.Generic
using namespace System.Collections
using namespace System.IO

class StructuredDataUtils {
    StructuredDataUtils([string]$filename) {
        
    }
    StructuredDataUtils([FileInfo]$filename) {
        
    }

    static [object] SetFileTypeUsingExtension ([string]$extension) {
        return switch -Regex ($extension) {
            ^.ya?ml$ {}
            ^.jso?n$ {}
            ^.csv$ {}
            ^.ini$ {}
            ^.xml$ {}
            ^.properties$ {}
            ^.txt$ {}
            ^.to?ml$ {}
            ^.psd1$ {}
            ^.ps1$ {}
        }
    }

    static [pscustomobject] ConvertFromGenericDictionary ([Dictionary[object, object]]$dictionary) {
        $obj = [PSCustomObject][hashtable]$dictionary
        Foreach ($entry in $dictionary.GetEnumerator()) {
            $value = if ( $entry.Value -is [Dictionary[object,object]]) {
                [StructuredDataUtils]::ConvertFromGenericDictionary($entry.Value)
            }
            elseif ( $entry.Value -is [KeyValuePair[object,object]]) {
                [StructuredDataUtils]::ConvertFromGenericDictionary($_.Value)
            }
            else {
                $entry.Value
            }
            $obj.($entry.Key) = $value
        }
        return $obj
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
