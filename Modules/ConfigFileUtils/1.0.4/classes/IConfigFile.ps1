class IConfigFile{

    IConfigFile(){
        $type = $this.GetType()
        if ( $type -eq [IConfigFile] ) {
            throw("Cannot instantiate object of type IConfigFile. This is an interface.")
        }
    }

    [PSCustomObject]Import() {
        throw("Method Import() has been inherited from the interface IConfigFile. This method must be overridden!")
    }

    [void]Export() {
        throw("Method Export() has been inherited from the interface IConfigFile. This method must be overridden!")
    }

    [PSCustomObject]ConvertFrom() {
        throw("Method ConvertFrom() has been inherited from the interface IConfigFile. This method must be overridden!")
    }

    [string[]]ConvertTo() {
        throw("Method ConvertTo() has been inherited from the interface IConfigFile. This method must be overridden!")
    }

}