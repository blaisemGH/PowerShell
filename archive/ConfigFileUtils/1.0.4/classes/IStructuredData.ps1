class IStructuredData {

    IStructuredData(){
        if ( $this.GetType() -eq [IStructuredData] ) {
            throw("Cannot instantiate object of type IStructuredData. This type is an interface only.")
        }
    }

    static [PSCustomObject]Import() {
        throw("Method Import() has been inherited from the interface IStructuredData. This method must be overridden!")
    }

    static [void]Export() {
        throw("Method Export() has been inherited from the interface IStructuredData. This method must be overridden!")
    }

    static [PSCustomObject]ConvertFrom() {
        throw("Method ConvertFrom() has been inherited from the interface IStructuredData. This method must be overridden!")
    }

    static [string[]]ConvertTo() {
        throw("Method ConvertTo() has been inherited from the interface IStructuredData. This method must be overridden!")
    }

}