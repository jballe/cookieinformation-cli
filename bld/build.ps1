param(
    $Version="0.4",
    $Registry="",
    $Name="jballe/cookieinformation-cli",
    [Switch]$Push
)

$ErrorActionPreference = "STOP"

$srcDir = Join-Path $PSScriptRoot ".." -Resolve
$buildDefPath = Join-Path $PSScriptRoot "build.json" -Resolve
$buildDef = Get-Content $buildDefPath | ConvertFrom-Json
Write-Host ("Found {0} build definitions" -f $buildDef.Length)
$buildDef | ForEach-Object {
    $buildDef = $_
    $tag = $buildDef.Tag.Replace("{VERSION}", $Version)
    $fullTag = "${Registry}${Name}:${Tag}"
    $base = $_.BaseImage
    Write-Host "Building $fullTag from base $base"
    & docker pull $base
    $LASTEXITCODE -ne 0 | Where-Object { $_ } | ForEach-Object { throw ("Failed, exitcode was {0}" -f $LASTEXITCODE) }
    & docker build -t $fullTag --build-arg BASE_IMAGE=$base $srcDir
    $LASTEXITCODE -ne 0 | Where-Object { $_ } | ForEach-Object { throw ("Failed, exitcode was {0}" -f $LASTEXITCODE) }

    if($Push) {
        & docker push $fullTag
        $LASTEXITCODE -ne 0 | Where-Object { $_ } | ForEach-Object { throw ("Failed, exitcode was {0}" -f $LASTEXITCODE) }
    }
}
