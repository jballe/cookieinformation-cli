# CookieInformation CLI

Small script to invoke internal api of [CookieInformation.com] to deploy configuration

## Usage

```
./cookieinformation.ps1 -Username <username> -Password <password> -ListSites
./cookieinformation.ps1 -Username <username> -Password <password> -SiteName "example.com" -ListDomains
./cookieinformation.ps1 -Username <username> -Password <password> -SiteName "example.com" -AddDomain -DomainName "test.example.com" -DomainType "internal_alias"
./cookieinformation.ps1 -Username <username> -Password <password> -SiteName "example.com" -RemoveDomain -DomainName "test.example.com"
./cookieinformation.ps1 -Username <username> -Password <password> -SiteName "example.com" -ExportToDisk -AssetsPath c:\temp
./cookieinformation.ps1 -Username <username> -Password <password> -SiteName "example.com" -ImportFromDisk -AssetsPath c:\temp
```

## License

It is GNU based so if you make changes to the tool, make it public as this.

Of course you can use the tool to deploy your private, custom, secret solutions without releasing your solutions publicly.
