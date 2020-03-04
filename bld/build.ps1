param(
    $Version="1.0",
    $Registry="",
    $Name="cookieinformation-cli",
    [Switch]$Push
)

$ErrorActionPreference = "STOP"

$srcDir = Join-Path $PSScriptRoot ".." -Resolve
(get-content (join-path $PSScriptRoot "build.json" -Resolve) | ConvertFrom-Json) | ForEach-Object {
    $buildDef = $_
    $tag = $buildDef.Tag.Replace("{VERSION}", $Version)
    $fullTag = "${Registry}${Name}:${Tag}"
    $base = $_.BaseImage
    Write-Host "Building $fullTag from base $base"
    & docker build -t $fullTag --build-arg BASE_IMAGE=$base $srcDir

    if($Push) {
        & docker push $fullTag
    }
}
