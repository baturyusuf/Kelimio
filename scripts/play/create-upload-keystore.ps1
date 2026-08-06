[CmdletBinding()]
param(
    [string]$KeystorePath,
    [string]$Alias = "kelimio-upload",
    [string]$DistinguishedName = "CN=Kelimio Upload, OU=Mobile, O=Kelimio, C=TR",
    [ValidateRange(3650, 36500)]
    [int]$ValidityDays = 9125,
    [switch]$Force
)

. (Join-Path $PSScriptRoot "common.ps1")

Assert-KelimioCommand "keytool"

$root = Get-KelimioRepositoryRoot
$androidDirectory = Join-Path $root "mobile/android"
if ([string]::IsNullOrWhiteSpace($KeystorePath)) {
    $KeystorePath = Join-Path $androidDirectory "keystores/kelimio-upload.p12"
}
$keystoreFullPath = [IO.Path]::GetFullPath($KeystorePath)

if (-not $keystoreFullPath.StartsWith(
    [IO.Path]::GetFullPath($androidDirectory),
    [StringComparison]::OrdinalIgnoreCase
)) {
    throw "The upload keystore must remain under mobile/android so key.properties can use a stable relative path."
}
if ((Test-Path -LiteralPath $keystoreFullPath) -and -not $Force) {
    throw "Keystore already exists. Use -Force only when you intentionally replace a key that has never been registered with Google Play."
}

$first = Read-Host "Upload keystore password (minimum 12 characters)" -AsSecureString
$second = Read-Host "Repeat upload keystore password" -AsSecureString

function ConvertTo-PlainText {
    param([Security.SecureString]$Value)
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Value)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
    }
}

$password = ConvertTo-PlainText $first
$confirmation = ConvertTo-PlainText $second
try {
    if ($password -cne $confirmation) {
        throw "Passwords do not match."
    }
    if ($password.Length -lt 12) {
        throw "Use an upload-key password of at least 12 characters."
    }
    if ($password.Contains("`n") -or $password.Contains("`r")) {
        throw "The password may not contain line breaks."
    }

    $parent = Split-Path -Parent $keystoreFullPath
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    if ($Force -and (Test-Path -LiteralPath $keystoreFullPath)) {
        Remove-Item -LiteralPath $keystoreFullPath -Force
    }

    $env:KELIMIO_UPLOAD_KEYSTORE_PASSWORD = $password
    try {
        Invoke-KelimioCommand keytool `
            -J-Duser.language=en `
            -genkeypair `
            -alias $Alias `
            -keyalg RSA `
            -keysize 4096 `
            -sigalg SHA256withRSA `
            -validity $ValidityDays `
            -dname $DistinguishedName `
            -storetype PKCS12 `
            -keystore $keystoreFullPath `
            -storepass:env KELIMIO_UPLOAD_KEYSTORE_PASSWORD `
            -keypass:env KELIMIO_UPLOAD_KEYSTORE_PASSWORD

        $certificatePath = [IO.Path]::ChangeExtension($keystoreFullPath, ".pem")
        Invoke-KelimioCommand keytool `
            -J-Duser.language=en `
            -exportcert `
            -rfc `
            -alias $Alias `
            -keystore $keystoreFullPath `
            -storetype PKCS12 `
            -storepass:env KELIMIO_UPLOAD_KEYSTORE_PASSWORD `
            -file $certificatePath

        $relativeStoreFile = $keystoreFullPath.Substring(
            [IO.Path]::GetFullPath($androidDirectory).TrimEnd("\", "/").Length
        ).TrimStart("\", "/").Replace("\", "/")
        $escapedPassword = $password.Replace("\", "\\")
        $keyPropertiesPath = Join-Path $androidDirectory "key.properties"
        @(
            "storeFile=$relativeStoreFile"
            "storePassword=$escapedPassword"
            "keyAlias=$Alias"
            "keyPassword=$escapedPassword"
        ) | Set-Content -LiteralPath $keyPropertiesPath -Encoding utf8

        Write-Host ""
        Write-Host "Upload key created:"
        Write-Host "  Keystore:       $keystoreFullPath"
        Write-Host "  Certificate:    $certificatePath"
        Write-Host "  Gradle config:  $keyPropertiesPath"
        Write-Host ""
        Write-Host "Certificate fingerprint:"
        & keytool `
            -J-Duser.language=en `
            -list `
            -v `
            -alias $Alias `
            -keystore $keystoreFullPath `
            -storetype PKCS12 `
            -storepass:env KELIMIO_UPLOAD_KEYSTORE_PASSWORD |
            Select-String -Pattern "SHA256:"
        if ($LASTEXITCODE -ne 0) {
            throw "Could not read the generated key fingerprint."
        }
    }
    finally {
        Remove-Item Env:KELIMIO_UPLOAD_KEYSTORE_PASSWORD -ErrorAction SilentlyContinue
    }
}
finally {
    $password = $null
    $confirmation = $null
}
