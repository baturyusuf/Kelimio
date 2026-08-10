[CmdletBinding()]
param(
    [ValidatePattern("^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$")]
    [string]$VersionName,

    [ValidateRange(1, 2100000000)]
    [int]$BuildNumber
)

. (Join-Path $PSScriptRoot "common.ps1")

$root = Get-KelimioRepositoryRoot
$pubspecPath = Join-Path $root "mobile/pubspec.yaml"
$content = Get-Content -LiteralPath $pubspecPath -Raw

$match = [regex]::Match(
    $content,
    "(?m)^version:\s*(?<name>[0-9A-Za-z.-]+)\+(?<build>\d+)\s*$"
)
if (-not $match.Success) {
    throw "Could not find a Flutter version line in mobile/pubspec.yaml."
}

$currentName = $match.Groups["name"].Value
$currentBuild = [int]$match.Groups["build"].Value
if ([string]::IsNullOrWhiteSpace($VersionName)) {
    $VersionName = $currentName
}
if ($BuildNumber -eq 0) {
    $BuildNumber = $currentBuild + 1
}
if ($BuildNumber -le $currentBuild -and $VersionName -eq $currentName) {
    throw "BuildNumber must be greater than the current build number for the same version name."
}

$replacement = "version: $VersionName+$BuildNumber"
$updated = $content.Substring(0, $match.Index) +
    $replacement +
    $content.Substring($match.Index + $match.Length)
Set-Content -LiteralPath $pubspecPath -Value $updated -Encoding utf8 -NoNewline

Write-Host "Updated mobile/pubspec.yaml:"
Write-Host "  $currentName+$currentBuild -> $VersionName+$BuildNumber"
