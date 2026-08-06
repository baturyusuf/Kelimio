[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$AabPath,

    [string]$BundletoolJar,

    [switch]$DownloadBundletool
)

. (Join-Path $PSScriptRoot "common.ps1")

Assert-KelimioCommand "java"
Assert-KelimioCommand "jarsigner"

$root = Get-KelimioRepositoryRoot
$aabFullPath = (Resolve-Path -LiteralPath $AabPath).Path
$playProperties = Read-KelimioProperties (
    Join-Path $root "mobile/android/play.properties"
)
$expectedApplicationId = $playProperties["applicationId"]
if ([string]::IsNullOrWhiteSpace($expectedApplicationId)) {
    throw "mobile/android/play.properties does not contain applicationId."
}

if ([string]::IsNullOrWhiteSpace($BundletoolJar)) {
    $BundletoolJar = Join-Path $root ".cache/bundletool/bundletool-all-1.18.3.jar"
}
$bundletoolFullPath = [IO.Path]::GetFullPath($BundletoolJar)
if (-not (Test-Path -LiteralPath $bundletoolFullPath)) {
    if (-not $DownloadBundletool) {
        throw "bundletool 1.18.3 was not found. Pass -DownloadBundletool or -BundletoolJar."
    }
    $bundletoolDirectory = Split-Path -Parent $bundletoolFullPath
    New-Item -ItemType Directory -Force -Path $bundletoolDirectory | Out-Null
    $bundletoolUrl =
        "https://github.com/google/bundletool/releases/download/1.18.3/" +
        "bundletool-all-1.18.3.jar"
    Write-Host "Downloading pinned bundletool 1.18.3 from the official Google repository..."
    Invoke-WebRequest -Uri $bundletoolUrl -OutFile $bundletoolFullPath
    Write-Host "bundletool SHA-256: $((Get-FileHash -LiteralPath $bundletoolFullPath -Algorithm SHA256).Hash)"
}

Invoke-KelimioCommand jarsigner -verify -strict -verbose -certs $aabFullPath
Invoke-KelimioCommand java -jar $bundletoolFullPath validate --bundle=$aabFullPath

$manifestPath = "$aabFullPath.manifest.xml"
& java -jar $bundletoolFullPath dump manifest --bundle=$aabFullPath --module=base |
    Set-Content -LiteralPath $manifestPath -Encoding utf8
if ($LASTEXITCODE -ne 0) {
    throw "bundletool could not dump the base manifest."
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw
$packageMatch = [regex]::Match($manifest, '\bpackage="(?<value>[^"]+)"')
if (-not $packageMatch.Success) {
    throw "Could not read the package name from the App Bundle manifest."
}
$actualApplicationId = $packageMatch.Groups["value"].Value
if ($actualApplicationId -ne $expectedApplicationId) {
    throw "AAB package '$actualApplicationId' does not match play.properties '$expectedApplicationId'."
}

$versionCodeMatch = [regex]::Match(
    $manifest,
    'android:versionCode="(?<value>\d+)"'
)
$versionNameMatch = [regex]::Match(
    $manifest,
    'android:versionName="(?<value>[^"]+)"'
)
$sha = (Get-FileHash -LiteralPath $aabFullPath -Algorithm SHA256).Hash.ToLowerInvariant()
"$sha  $([IO.Path]::GetFileName($aabFullPath))" |
    Set-Content -LiteralPath "$aabFullPath.sha256" -Encoding ascii

Write-Host ""
Write-Host "AAB verification passed:"
Write-Host "  Package:     $actualApplicationId"
if ($versionNameMatch.Success) {
    Write-Host "  Version:     $($versionNameMatch.Groups["value"].Value)"
}
if ($versionCodeMatch.Success) {
    Write-Host "  Version code: $($versionCodeMatch.Groups["value"].Value)"
}
Write-Host "  SHA-256:     $sha"
Write-Host "  Manifest:    $manifestPath"
