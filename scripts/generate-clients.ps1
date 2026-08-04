$ErrorActionPreference = "Stop"

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$contractPath = Join-Path $repositoryRoot "contracts/openapi/kelimio-api.yaml"
$mobileOutput = Join-Path $repositoryRoot "mobile/packages/kelimio_api_client"
$webOutput = Join-Path $repositoryRoot "admin-web/src/generated/api"
$dartLockPath = Join-Path $mobileOutput "pubspec.lock"
# openapitools/openapi-generator-cli v7.14.0
$generatorImage = "openapitools/openapi-generator-cli@sha256:a620610d9fabf7ce05310c648417ba168125aac2f4517580030e115921ac1a52"
$generatorJar = $env:OPENAPI_GENERATOR_JAR
$generatorJarSha256 = "e03186835022ca02da4aa95e3967b6a3b6d44c2e5f7606e6d5c22466f519c757"
$useDocker = [bool](Get-Command docker -ErrorAction SilentlyContinue)
$dartLockBytes = if (Test-Path -LiteralPath $dartLockPath) {
    [System.IO.File]::ReadAllBytes($dartLockPath)
} else {
    $null
}

function Remove-GeneratedOutput {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    $rootPath = [System.IO.Path]::GetFullPath($repositoryRoot).TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    )
    $targetPath = [System.IO.Path]::GetFullPath($Path)
    $requiredPrefix = $rootPath + [System.IO.Path]::DirectorySeparatorChar
    if (-not $targetPath.StartsWith($requiredPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to clean generated output outside the repository: $targetPath"
    }
    if (Test-Path -LiteralPath $targetPath) {
        Remove-Item -LiteralPath $targetPath -Recurse -Force
    }
}

function Normalize-GeneratedText {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    $utf8WithoutBom = [System.Text.UTF8Encoding]::new($false)
    $textExtensions = @(".dart", ".json", ".md", ".ts", ".yaml", ".yml")
    $textFileNames = @(".gitignore", ".openapi-generator-ignore", "pubspec.lock", "pubspec.yaml")

    Get-ChildItem -LiteralPath $Path -Recurse -File | Where-Object {
        $_.Extension -in $textExtensions -or $_.Name -in $textFileNames
    } | ForEach-Object {
        $content = [System.IO.File]::ReadAllText($_.FullName)
        $normalized = [System.Text.RegularExpressions.Regex]::Replace(
            $content,
            '[\t ]+(?=\r?\n|$)',
            ''
        )
        $normalized = [System.Text.RegularExpressions.Regex]::Replace(
            $normalized,
            '(\r?\n)+\z',
            "`n"
        )
        [System.IO.File]::WriteAllText($_.FullName, $normalized, $utf8WithoutBom)
    }
}

function Repair-GeneratedTypeScriptNullableDates {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    # OpenAPI Generator 7.14 emits a direct toISOString() call for a required
    # nullable date/date-time. The cast is emitted only for nullable values, so
    # this narrowly repairs that unsafe shape while leaving required dates and
    # optional-nullable dates unchanged.
    $unsafePattern = "(?m)^(?<indent>\s*)'(?<baseName>[^']+)': \(\(value\['(?<name>[^']+)'\] as any\)\.toISOString\(\)(?<dateOnly>\.substring\(0,10\))?\),"
    $utf8WithoutBom = [System.Text.UTF8Encoding]::new($false)
    $replacement = [System.Text.RegularExpressions.MatchEvaluator] {
        param([System.Text.RegularExpressions.Match] $match)

        $indent = $match.Groups['indent'].Value
        $baseName = $match.Groups['baseName'].Value
        $name = $match.Groups['name'].Value
        $dateOnly = $match.Groups['dateOnly'].Value
        return "$indent'$baseName': value['$name'] == null ? null : ((value['$name'] as any).toISOString()$dateOnly),"
    }

    Get-ChildItem -LiteralPath $Path -Recurse -File -Filter "*.ts" | ForEach-Object {
        $content = [System.IO.File]::ReadAllText($_.FullName)
        $repaired = [System.Text.RegularExpressions.Regex]::Replace(
            $content,
            $unsafePattern,
            $replacement,
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
        )
        if ($repaired -ne $content) {
            [System.IO.File]::WriteAllText($_.FullName, $repaired, $utf8WithoutBom)
        }
    }

    $remaining = Get-ChildItem -LiteralPath $Path -Recurse -File -Filter "*.ts" | Where-Object {
        [System.Text.RegularExpressions.Regex]::IsMatch(
            [System.IO.File]::ReadAllText($_.FullName),
            $unsafePattern,
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
        )
    }
    if ($remaining) {
        throw "Generated TypeScript retains an unsafe required-nullable date serializer."
    }
}

function Invoke-OpenApiGenerator {
    param(
        [Parameter(Mandatory = $true)]
        [string[]] $Arguments
    )

    if ($useDocker) {
        $dockerArguments = @("run", "--rm")
        if ($env:OS -ne "Windows_NT") {
            if (-not (Get-Command id -ErrorAction SilentlyContinue)) {
                throw "The Unix id command is required to map generated files to the host user."
            }
            $hostUid = (& id -u).Trim()
            $hostGid = (& id -g).Trim()
            if ($LASTEXITCODE -ne 0 -or $hostUid -notmatch '^\d+$' -or $hostGid -notmatch '^\d+$') {
                throw "Unable to resolve the host UID/GID for OpenAPI generation."
            }
            $dockerArguments += @("--user", "${hostUid}:${hostGid}")
        }
        $dockerArguments += @("-v", "${repositoryRoot}:/workspace", $generatorImage)
        docker @dockerArguments @Arguments
        if ($LASTEXITCODE -ne 0) {
            throw "OpenAPI Generator container failed with exit code $LASTEXITCODE."
        }
        return
    }

    if ($generatorJar -and (Test-Path -LiteralPath $generatorJar) -and (Get-Command java -ErrorAction SilentlyContinue)) {
        $actualJarSha256 = (Get-FileHash -LiteralPath $generatorJar -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actualJarSha256 -ne $generatorJarSha256) {
            throw "OpenAPI Generator JAR checksum mismatch; expected the pinned 7.14.0 artifact."
        }
        java -jar $generatorJar @Arguments
        if ($LASTEXITCODE -ne 0) {
            throw "OpenAPI Generator JAR failed with exit code $LASTEXITCODE."
        }
        return
    }

    throw "Install Docker, or set OPENAPI_GENERATOR_JAR to the pinned 7.14.0 CLI JAR and place Java 21 on PATH."
}

$contractArgument = if ($useDocker) {
    "/workspace/contracts/openapi/kelimio-api.yaml"
} else {
    "contracts/openapi/kelimio-api.yaml"
}
$dartConfigArgument = if ($useDocker) {
    "/workspace/contracts/generator-config/dart.yaml"
} else {
    "contracts/generator-config/dart.yaml"
}
$typescriptConfigArgument = if ($useDocker) {
    "/workspace/contracts/generator-config/typescript-fetch.yaml"
} else {
    "contracts/generator-config/typescript-fetch.yaml"
}
$dartTemplateArgument = if ($useDocker) {
    "/workspace/contracts/generator-templates/dart-dio"
} else {
    "contracts/generator-templates/dart-dio"
}
$mobileOutputArgument = if ($useDocker) {
    "/workspace/mobile/packages/kelimio_api_client"
} else {
    "mobile/packages/kelimio_api_client"
}
$webOutputArgument = if ($useDocker) {
    "/workspace/admin-web/src/generated/api"
} else {
    "admin-web/src/generated/api"
}

Remove-GeneratedOutput -Path $mobileOutput
Remove-GeneratedOutput -Path $webOutput

Push-Location $repositoryRoot
try {
    Invoke-OpenApiGenerator -Arguments @(
        "generate", "-i", $contractArgument,
        "-g", "dart-dio",
        "-c", $dartConfigArgument,
        "-t", $dartTemplateArgument,
        "-o", $mobileOutputArgument
    )

    Invoke-OpenApiGenerator -Arguments @(
        "generate", "-i", $contractArgument,
        "-g", "typescript-fetch",
        "-c", $typescriptConfigArgument,
        "-o", $webOutputArgument
    )
} finally {
    Pop-Location
}

if (-not (Get-Command dart -ErrorAction SilentlyContinue)) {
    throw "Dart 3.12 from the pinned Flutter 3.44 SDK is required to build generated serializers."
}

Push-Location $mobileOutput
try {
    if ($null -ne $dartLockBytes) {
        [System.IO.File]::WriteAllBytes($dartLockPath, $dartLockBytes)
        dart pub get --enforce-lockfile
    } else {
        dart pub get
    }
    if ($LASTEXITCODE -ne 0) {
        throw "Generated Dart client dependency resolution failed with exit code $LASTEXITCODE."
    }
    dart run build_runner build --delete-conflicting-outputs
    if ($LASTEXITCODE -ne 0) {
        throw "Generated Dart serializer build failed with exit code $LASTEXITCODE."
    }
    dart format .
    if ($LASTEXITCODE -ne 0) {
        throw "Generated Dart client formatting failed with exit code $LASTEXITCODE."
    }
} finally {
    Pop-Location
}

Repair-GeneratedTypeScriptNullableDates -Path $webOutput
Normalize-GeneratedText -Path $mobileOutput
Normalize-GeneratedText -Path $webOutput

Write-Host "Generated clients from $contractPath into $mobileOutput and $webOutput"
