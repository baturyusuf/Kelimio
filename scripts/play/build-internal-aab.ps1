[CmdletBinding()]
param(
    [string]$ConfigPath,
    [string]$OutputDirectory,
    [switch]$SkipTests,
    [switch]$Clean
)

. (Join-Path $PSScriptRoot "common.ps1")

Assert-KelimioCommand "flutter"
Assert-KelimioCommand "dart"
Assert-KelimioCommand "java"
Assert-KelimioCommand "jarsigner"

$root = Get-KelimioRepositoryRoot
$mobileDirectory = Join-Path $root "mobile"
if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    $ConfigPath = Join-Path $mobileDirectory "config/play.internal.json"
}
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $root "output/play-internal"
}

$configFullPath = (Resolve-Path -LiteralPath $ConfigPath).Path
$keyPropertiesPath = Join-Path $mobileDirectory "android/key.properties"
$playPropertiesPath = Join-Path $mobileDirectory "android/play.properties"
if (-not (Test-Path -LiteralPath $keyPropertiesPath)) {
    throw "Missing $keyPropertiesPath. Run create-upload-keystore.ps1 first."
}
$playProperties = Read-KelimioProperties $playPropertiesPath
if ($playProperties["applicationId"] -eq "com.kelimio.app") {
    throw "The scaffold applicationId cannot be uploaded to Google Play."
}

$config = Get-Content -LiteralPath $configFullPath -Raw | ConvertFrom-Json
Assert-KelimioHttpsUri -Name "KELIMIO_API_BASE_URL" -Value $config.KELIMIO_API_BASE_URL | Out-Null
Assert-KelimioHttpsUri -Name "KELIMIO_OIDC_ISSUER" -Value $config.KELIMIO_OIDC_ISSUER | Out-Null
if ($config.KELIMIO_INTERNAL_TEST_MODE -ne "true") {
    throw "KELIMIO_INTERNAL_TEST_MODE must be the string 'true'."
}
if ($config.KELIMIO_LOCAL_DEVELOPMENT_TOOLS -ne "false") {
    throw "KELIMIO_LOCAL_DEVELOPMENT_TOOLS must remain false in a Google Play build."
}

Push-Location $mobileDirectory
try {
    if ($Clean) {
        Invoke-KelimioCommand flutter clean
    }
    Invoke-KelimioCommand flutter pub get --enforce-lockfile
    Invoke-KelimioCommand flutter gen-l10n

    if (-not $SkipTests) {
        Invoke-KelimioCommand dart format --output=none --set-exit-if-changed .
        Invoke-KelimioCommand flutter analyze --fatal-infos
        Invoke-KelimioCommand flutter test
    }

    Invoke-KelimioCommand flutter build appbundle `
        --release `
        --flavor production `
        --dart-define-from-file=$configFullPath
}
finally {
    Pop-Location
}

$aabCandidates = @(
    (Join-Path $mobileDirectory "build/app/outputs/bundle/productionRelease/app-production-release.aab"),
    (Join-Path $mobileDirectory "build/app/outputs/bundle/release/app-release.aab")
)
$aabPath = $aabCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $aabPath) {
    $aabPath = Get-ChildItem `
        -Path (Join-Path $mobileDirectory "build/app/outputs/bundle") `
        -Filter "*.aab" `
        -Recurse |
        Sort-Object LastWriteTimeUtc -Descending |
        Select-Object -First 1 -ExpandProperty FullName
}
if (-not $aabPath) {
    throw "Flutter completed but no AAB was found."
}

$pubspec = Get-Content -LiteralPath (Join-Path $mobileDirectory "pubspec.yaml") -Raw
$versionMatch = [regex]::Match(
    $pubspec,
    "(?m)^version:\s*(?<name>[0-9A-Za-z.-]+)\+(?<build>\d+)\s*$"
)
if (-not $versionMatch.Success) {
    throw "Could not read the app version from mobile/pubspec.yaml."
}
$version = "$($versionMatch.Groups["name"].Value)+$($versionMatch.Groups["build"].Value)"
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$destination = Join-Path $OutputDirectory "kelimio-$version.aab"
Copy-Item -LiteralPath $aabPath -Destination $destination -Force

& (Join-Path $PSScriptRoot "verify-internal-aab.ps1") `
    -AabPath $destination `
    -DownloadBundletool
if ($LASTEXITCODE -ne 0) {
    throw "AAB verification failed."
}

Write-Host ""
Write-Host "Google Play internal-test bundle is ready:"
Write-Host "  $destination"
