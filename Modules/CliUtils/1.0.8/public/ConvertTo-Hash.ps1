function ConvertTo-Hash {
    param(
        [Parameter(Mandatory)]
        [string[]]$InputObject,

        [Parameter(Mandatory)]
        [ValidateSet('MD5','SHA1','SHA256','SHA384','SHA512')]
        [string]$Hash
    )
    begin {
        $cryptography = switch ($Hash) {
            MD5     {[Security.Cryptography.MD5CryptoServiceProvider]::new()}
            SHA1    {[Security.Cryptography.SHA1CryptoServiceProvider]::new()}
            SHA256  {[Security.Cryptography.SHA256CryptoServiceProvider]::new()}
            SHA384  {[Security.Cryptography.SHA384CryptoServiceProvider]::new()}
            SHA512  {[Security.Cryptography.SHA512CryptoServiceProvider]::new()}
        }
    }
    process {
        foreach ($string in $InputObject) {
            $bytes = [Text.UTF8Encoding]::new().GetBytes($string)
            $hashedBytes = $cryptography.ComputeHash($bytes)
            [BitConverter]::ToString($hashedBytes).Replace("-","")
        }
    }
}