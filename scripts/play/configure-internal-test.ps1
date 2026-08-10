[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern("^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$")]
    [string]$ApplicationId,

    [Parameter(Mandatory = $true)]
    [string]$ApiBaseUrl,

    [Parameter(Mandatory = $true)]
    [string]$OidcIssuer,

    [Parameter(Mandatory = $true)]
    [string]$OidcClientId,

    [string]$AppLabel = "Kelimio",

    # This scheme is already registered in the current production Cognito client.
    # It intentionally remains independent from the immutable Play applicationId.
    [ValidatePattern("^[a-z][a-z0-9+.-]*$")]
    [string]$RedirectScheme = "com.kelimio.app",

    [switch]$SetGitHubVariables
)

. (Join-Path $PSScriptRoot "common.ps1")

if ($ApplicationId -eq "com.kelimio.app") {
    throw "com.kelimio.app is the repository scaffold identifier. Select the permanent Google Play applicationId before the first upload."
}
if ($OidcClientId.Trim().Length -eq 0) {
    throw "OidcClientId may not be blank."
}

$apiUri = Assert-KelimioHttpsUri -Name "ApiBaseUrl" -Value $ApiBaseUrl
$issuerUri = Assert-KelimioHttpsUri -Name "OidcIssuer" -Value $OidcIssuer

$root = Get-KelimioRepositoryRoot
$androidDirectory = Join-Path $root "mobile/android"
$configDirectory = Join-Path $root "mobile/config"
New-Item -ItemType Directory -Force -Path $configDirectory | Out-Null

$playPropertiesPath = Join-Path $androidDirectory "play.properties"
@(
    "applicationId=$ApplicationId"
    "appLabel=$AppLabel"
    "redirectScheme=$RedirectScheme"
) | Set-Content -LiteralPath $playPropertiesPath -Encoding utf8

$configPath = Join-Path $configDirectory "play.internal.json"
$config = [ordered]@{
    KELIMIO_API_BASE_URL = $apiUri.AbsoluteUri.TrimEnd("/")
    KELIMIO_OIDC_ISSUER = $issuerUri.AbsoluteUri.TrimEnd("/")
    KELIMIO_OIDC_CLIENT_ID = $OidcClientId.Trim()
    KELIMIO_OIDC_REDIRECT_URI = "${RedirectScheme}:/oauthredirect"
    KELIMIO_OIDC_POST_LOGOUT_REDIRECT_URI = "${RedirectScheme}:/logout"
    KELIMIO_INTERNAL_TEST_MODE = "true"
    KELIMIO_LOCAL_DEVELOPMENT_TOOLS = "false"
}
$config | ConvertTo-Json | Set-Content -LiteralPath $configPath -Encoding utf8

if ($SetGitHubVariables) {
    Assert-KelimioCommand "gh"
    Invoke-KelimioCommand gh auth status
    Invoke-KelimioCommand gh variable set ANDROID_APPLICATION_ID --body $ApplicationId
    Invoke-KelimioCommand gh variable set ANDROID_REDIRECT_SCHEME --body $RedirectScheme
    Invoke-KelimioCommand gh variable set KELIMIO_API_BASE_URL --body $config.KELIMIO_API_BASE_URL
    Invoke-KelimioCommand gh variable set KELIMIO_OIDC_ISSUER --body $config.KELIMIO_OIDC_ISSUER
    Invoke-KelimioCommand gh variable set KELIMIO_OIDC_CLIENT_ID --body $config.KELIMIO_OIDC_CLIENT_ID
}

Write-Host "Internal-test mobile configuration written:"
Write-Host "  $playPropertiesPath"
Write-Host "  $configPath"
Write-Host ""
Write-Host "The redirect scheme remains '$RedirectScheme'; the Google Play applicationId is '$ApplicationId'."
Write-Host "Neither generated file is tracked by Git."
