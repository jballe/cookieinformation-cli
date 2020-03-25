[CmdletBinding(DefaultParametersetName = "None")] 
param(
    [Parameter(ParameterSetName = "None", Mandatory = $true)]
    $Username,
    [Parameter(ParameterSetName = "None", Mandatory = $true)]
    $Password,
    $SiteId = $null,
    $SiteName = $null,
    $DomainName = $null,
    [ValidateSet("internal_alias", "external_alias", "website")]
    $DomainType = "internal_alias",
    $AssetsPath = (Join-Path $PSScriptRoot "assets"),
    [Switch]$ListSites,
    [Switch]$ListDomains,
    [Switch]$AddDomain,
    [Switch]$RemoveDomain,
    [Switch]$ExportToDisk=$True,
    [Switch]$ImportFromDisk,
    [Parameter(ParameterSetName = "Help", Mandatory = $true)]
    [Switch]$Help
)

$global:token = ""
$global:urlBase = "https://api.app.cookieinformation.com"
$global:templates = @("popUpTemplate", "declarationTemplate", "choiceBoxTemplate")
$global:assetTypes = @("js", "css", "html")

$ErrorActionPreference = "STOP"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Login {
    param(
        $Email,
        $Pwd
    )
    $login = Post -Path "/login_check" -Data @{ email = $Email; password = $Pwd } -Accept "*/*" -ContentType "application/json"
    $token = $login.token
    $global:token = "Bearer ${token}"
}

function Get {
    param($Path)

    $headers = @{
        Authorization = $global:token
    }

    $uri = "https://api.app.cookieinformation.com${Path}"
    $result = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get -Body ($data | ConvertTo-Json) 
    $result
}

function Post {
    param(
        $Data, 
        $Path,
        $Accept = "application/ld+json",
        $ContentType = "application/ld+json",
        $Verb = "Post"
    )

    $headers = @{
        Referer           = "${global:UrlBase}/"
        Origin            = $global:UrlBase
        "Accept-Language" = "en-US"
        Accept            = $Accept 
    }
    If ("${global:token}" -ne "") {
        $headers["Authorization"] = $global:token
    }

    $uri = "https://api.app.cookieinformation.com${Path}"
    $json = $Data | ConvertTo-Json
    $result = Invoke-RestMethod -Uri $uri -Headers $headers -Method $Verb -Body $json -ContentType $ContentType
    $result
}

function Delete {
    param($Path)

    $headers = @{
        Authorization = $global:token
    }

    $uri = "https://api.app.cookieinformation.com${Path}"
    $result = Invoke-RestMethod -Uri $uri -Headers $headers -Method Delete
    $result

}

function GetWebsites {
    $data = Get -Path "/websites"
    $sites = $data."hydra:member"
    $sites
}

function GetWebsiteData {
    param(
        [int]$SiteId,
        [string]$Name
    )

    if ($SiteId -gt 0) {
        $data = Get -Path "/websites/${SiteId}"
    } Else {
        $data = GetWebsites | Where-Object { $_.name -ieq $Name } | Select-Object -First 1
    }
    $data
}

function GetDomains {
    param(
        [int]$SiteId
    )

    $siteData = GetWebsiteData -SiteId $SiteId
    $domains = $siteData.domains
    $domains
}

function GetDomain {
    param(
        [int]$SiteId,
        [string]$HostName
    )

    $domains = GetDomains -SiteId $SiteId
    $entry = $domains | Where-Object { $_.canonicalDomain -eq $HostName }
    $entry

}

function ExecuteAddDomain {
    param(
        [int]$SiteId,
        [string]$HostName,
        [string]$Type = "internal_alias",
        [string][ValidateSet("DA", "EN")] $LanguageCode = "DA"
    )

    $domain = GetDomain -SiteId $SiteId -HostName $HostName
    If ($Null -ne $domain) {
        Write-Host "Domain ${HostName} already exists, will not attempt to create"
        Return
    }

    Post -Path "/domains" -Data @{
        canonicalDomain = $HostName
        displayedDomain = $HostName
        defaultLang     = "/languages/${LanguageCode}"
        type            = $Type
        website         = "/websites/${SiteId}"
    }
}

function ExecuteRemoveDomain {
    param(
        [int]$SiteId,
        [string]$HostName
    )

    $domain = GetDomain -SiteId $SiteId -HostName $HostName
    If ($Null -eq $domain) {
        Write-Host "Domain ${HostName} not found so we will not attempt to remove"
        Return

    }
    $domainPath = $domain | Select-Object -First 1 -ExpandProperty "@id"
    Delete -Path $domainPath | Out-Null
}

function SaveWebsiteAssets {
    param(
        $Path,
        $SiteId = $Null,
        $Site = $Null
    )

    if ($Null -eq $Site) {
        $Site = GetWebsiteData -SiteId $SiteId
    }

    If ($Null -eq $Site) {
        Write-Error "No site found with id ${SiteId}"
        Return
    }

    $Site.date = $Null
    $Site.account.date = $Null

    @("domains", "cookieConsentTexts") | ForEach-Object {
        $sectionKey = $_
        $Site.$sectionKey | ForEach-Object {
            $obj = $_
            if ($Null -ne $obj.date) {
                $obj.date = $Null
            }
            @("languages", "defaultLang") | ForEach-Object {
                $key = $_
                if ($Null -ne $obj.$key.date) {
                    $obj.$key.date = $Null
                }
            }
        }
    }

    if (-not (Test-Path $Path)) { new-item $Path -ItemType Directory | Out-Null }
    $global:templates | ForEach-Object {
        $name = $_
        $obj = $Site.$name
        $obj.date = $Null
        $objPath = Join-Path $Path $name
        $global:assetTypes | ForEach-Object {
            $assetType = $_
            $asset = $obj.$assetType.Trim()
            If ($Null -ne $asset) {
                Set-Content -Path "${objPath}.${assetType}" -Value $asset | Out-Null
                $obj.$assetType = "##see file##"
            }
        }
    }

    $Site | ConvertTo-Json -Depth 6 | Set-Content -Path (Join-Path $Path "assets.json") -Encoding UTF8 | Out-Null
}

function LoadAssetsToSite {
    param(
        # Path to folder with asset files
        [Parameter(Mandatory = $True)]
        [string]$Path,

        $Site,

        $Parts = @("popUpTemplate")
    )

    if ($Null -eq $Site) {
        $Site = GetWebsiteData -SiteId $SiteId
    }

    If ($Null -eq $Site) {
        Write-Error "No site found with id ${SiteId}"
        Return
    }

    $assetData = Get-Content (Join-Path $Path "assets.json") | ConvertFrom-Json
    $result = @{
        "@id"   = $assetData."@id"
        "@type" = $assetData."@type"
        id      = $assetData.id
        name    = $assetData.name
        account = $assetData.account
    }

    $global:templates | ForEach-Object {
        $name = $_
        $obj = $assetData.$name

        $objPath = Join-Path $Path $name
        $global:assetTypes | ForEach-Object {
            $assetType = $_
            $assetPath = "${objPath}.${assetType}"
            if (Test-Path $assetPath) {
                [string]$asset = Get-Content $assetPath -Raw -Encoding utf8
            } Else {
                $asset = $Null
            }
            $obj.$assetType = $asset
        }
        $result.$name = $obj
    }

    $uri = $Site."@id"
    Post -Path $uri -Data $result -Verb Put -Verbose | Out-Null
}

If($Null -ne $Username -or -not $Help) {
    Write-Host "Logging in..."
    Login -Email $Username -Pwd $Password
}

if ($ListSites) {
    Write-Host "Get Website..."
    $webs = GetWebsites
    $webs | Format-Table -Property id, name
}

If ($Null -ne $SiteId) {
    $site = GetWebsiteData -SiteId $SiteId
} elseif ($Null -ne $SiteName) {
    $site = GetWebsiteData -Name $SiteName    
}

If ($Null -eq $site -and ($SiteId -or $SiteName)) {
    Write-Error "Could not find site"
    return
} ElseIf($Null -ne $site) {
    $siteName = $site | Select-Object -ExpandProperty name
    $siteId = $site.id
}

If ($AddDomain) {
    Write-Host "Adding domain..."
    ExecuteAddDomain -SiteId $siteId -HostName $DomainName -Type $DomainType
    Write-Host "Added domain to ${siteName} ($siteId)" -ForegroundColor Green
} elseif ($RemoveDomain) {
    Write-Host "Removing domain..."
    RemoveDomain -SiteId $siteId -HostName $DomainName
    Write-Host "Removed domain $DomainName from ${siteName} ($siteId)" -ForegroundColor Green
}

If ($ListDomains) {
    Write-Host "Fetch domains..."
    $site.domains | Format-Table -property "type", canonicalDomain
}

if ($ImportFromDisk) {
    Write-Host "Import assets..."
    LoadAssetsToSite -Site $site -Path $AssetsPath
    Write-Host "Imported ${siteName} ($siteId) from disk to site" -ForegroundColor Green
}

if ($ExportToDisk) {
    Write-Host "Export assets..."
    SaveWebsiteAssets -Site $site -Path $AssetsPath
    Write-Host "Exported ${siteName} ($siteId) to disk" -ForegroundColor Green
}

if ($Help) {
    Write-Host "CookieInformation CLI"
    Write-Host "./cookieinformation.ps1 -Username <username> -Password <password> -ListSites"
    Write-Host "./cookieinformation.ps1 -Username <username> -Password <password> -SiteName `"example.com`" -ListDomains"
    Write-Host "./cookieinformation.ps1 -Username <username> -Password <password> -SiteName `"example.com`" -AddDomain -DomainName `"test.example.com`" -DomainType `"internal_alias`""
    Write-Host "./cookieinformation.ps1 -Username <username> -Password <password> -SiteName `"example.com`" -RemoveDomain -DomainName `"test.example.com`""
    Write-Host "./cookieinformation.ps1 -Username <username> -Password <password> -SiteName `"example.com`" -ExportToDisk -AssetsPath c:\temp"
    Write-Host "./cookieinformation.ps1 -Username <username> -Password <password> -SiteName `"example.com`" -ImportFromDisk -AssetsPath c:\temp"

}
