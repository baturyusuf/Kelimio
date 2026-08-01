[CmdletBinding()]
param(
    [string] $DeviceId = "emulator-5554",
    [ValidateRange(120, 900)]
    [int] $StartupTimeoutSeconds = 420
)

$ErrorActionPreference = "Stop"

$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$composePath = Join-Path $repositoryRoot "compose.yaml"
$mobilePath = Join-Path $repositoryRoot "mobile"
$testPath = "integration_test/real_local_auth_to_progress_test.dart"
$projectPattern = '^kelimio-e2e-[0-9a-f]{12}$'
$environmentNames = @(
    "KELIMIO_LOCAL_DB_PASSWORD",
    "KELIMIO_LOCAL_KEYCLOAK_ADMIN",
    "KELIMIO_LOCAL_KEYCLOAK_PASSWORD",
    "KELIMIO_LOCAL_POSTGRES_HOST_PORT",
    "KELIMIO_LOCAL_REDIS_HOST_PORT",
    "KELIMIO_LOCAL_LOCALSTACK_HOST_PORT",
    "KELIMIO_LOCALSTACK_IMAGE",
    "KELIMIO_LOCAL_KEYCLOAK_HOST_PORT",
    "KELIMIO_LOCAL_MAILPIT_SMTP_HOST_PORT",
    "KELIMIO_LOCAL_MAILPIT_HTTP_HOST_PORT",
    "KELIMIO_LOCAL_API_HOST_PORT",
    "KELIMIO_LOCAL_KEYCLOAK_BASE_URL",
    "KELIMIO_LOCAL_OIDC_ISSUER",
    "KELIMIO_LOCAL_RESTART_POLICY"
)

function New-RandomHex {
    param([ValidateRange(1, 64)][int] $ByteCount)

    $bytes = New-Object byte[] $ByteCount
    $generator = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $generator.GetBytes($bytes)
    } finally {
        $generator.Dispose()
    }
    return ($bytes | ForEach-Object { $_.ToString("x2") }) -join ""
}

function New-RandomSecret {
    $bytes = New-Object byte[] 32
    $generator = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $generator.GetBytes($bytes)
    } finally {
        $generator.Dispose()
    }
    return [Convert]::ToBase64String($bytes).Replace("+", "-").Replace("/", "_").TrimEnd("=")
}

function Get-AvailableLoopbackPort {
    param([System.Collections.Generic.HashSet[int]] $ReservedPorts)

    for ($attempt = 0; $attempt -lt 50; $attempt++) {
        $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
        try {
            $listener.Start()
            $port = ([System.Net.IPEndPoint] $listener.LocalEndpoint).Port
        } finally {
            $listener.Stop()
        }
        if ($port -ge 20000 -and $ReservedPorts.Add($port)) {
            return $port
        }
    }
    throw "Unable to reserve an unused loopback port for the isolated test."
}

function Resolve-Adb {
    $candidates = @(
        $env:ANDROID_SDK_ROOT,
        $env:ANDROID_HOME,
        [Environment]::GetEnvironmentVariable("ANDROID_SDK_ROOT", "User"),
        [Environment]::GetEnvironmentVariable("ANDROID_HOME", "User"),
        (Join-Path $env:LOCALAPPDATA "Android\Sdk")
    ) | Where-Object { $_ }

    foreach ($candidate in $candidates) {
        $path = Join-Path ([System.IO.Path]::GetFullPath($candidate)) "platform-tools\adb.exe"
        if (Test-Path -LiteralPath $path) {
            return $path
        }
    }
    throw "Android platform tools are missing. Run scripts/android-emulator.ps1 -Action setup first."
}

function Get-AdbReverseMappings {
    param([string] $Adb, [string] $Serial)

    $output = @(& $Adb -s $Serial reverse --list 2>$null)
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to inspect Android reverse-port mappings."
    }
    return @($output | Where-Object { $_ })
}

function Test-AndroidPackageInstalled {
    param([string] $Adb, [string] $Serial, [string] $PackageName)

    if ($PackageName -notin @("com.kelimio.app", "com.kelimio.app.e2e")) {
        throw "The Android package guard rejected the inspection target."
    }
    $packages = @(& $Adb -s $Serial shell pm list packages $PackageName 2>$null)
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to inspect a guarded Android package."
    }
    $matches = @($packages | Where-Object { $_.Trim() -eq "package:$PackageName" })
    if ($matches.Count -gt 1) {
        throw "The guarded Android package lookup was ambiguous."
    }
    return $matches.Count -eq 1
}

function Remove-E2eAndroidApplication {
    param([string] $Adb, [string] $Serial)

    $packageName = "com.kelimio.app.e2e"
    if (Test-AndroidPackageInstalled -Adb $Adb -Serial $Serial -PackageName $packageName) {
        $result = ((& $Adb -s $Serial uninstall $packageName 2>$null) -join "").Trim()
        if ($LASTEXITCODE -ne 0 -or $result -ne "Success") {
            throw "Unable to remove the isolated Android test package."
        }
    }
}

function Get-ComposeConfiguration {
    param([string] $Docker, [string] $Project)

    $json = (& $Docker compose -f $composePath -p $Project --profile app config --format json 2>$null) -join "`n"
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($json)) {
        throw "Unable to resolve the isolated Compose configuration."
    }
    return $json | ConvertFrom-Json
}

function Assert-IsolatedComposeConfiguration {
    param(
        [object] $Configuration,
        [string] $Project,
        [hashtable] $Ports
    )

    if ($Project -notmatch $projectPattern -or $Configuration.name -ne $Project) {
        throw "The resolved Compose project did not pass the isolated-project guard."
    }
    foreach ($property in $Configuration.volumes.PSObject.Properties) {
        $volume = $property.Value
        if ($volume.external -eq $true -or -not $volume.name.StartsWith("${Project}_")) {
            throw "The isolated Compose configuration contains an unsafe volume."
        }
    }

    $expected = @(
        @{ Service = "postgres"; Target = 5432; Published = $Ports.Postgres },
        @{ Service = "redis"; Target = 6379; Published = $Ports.Redis },
        @{ Service = "localstack"; Target = 4566; Published = $Ports.LocalStack },
        @{ Service = "keycloak"; Target = 8080; Published = $Ports.Keycloak },
        @{ Service = "mailpit"; Target = 1025; Published = $Ports.MailpitSmtp },
        @{ Service = "mailpit"; Target = 8025; Published = $Ports.MailpitHttp },
        @{ Service = "api"; Target = 8080; Published = $Ports.Api }
    )
    foreach ($item in $expected) {
        $service = $Configuration.services.($item.Service)
        $binding = @($service.ports | Where-Object { [int] $_.target -eq $item.Target })
        if ($binding.Count -ne 1 -or
            $binding[0].host_ip -ne "127.0.0.1" -or
            [int] $binding[0].published -ne $item.Published) {
            throw "The isolated Compose port guard rejected a service binding."
        }
    }
    if ($Configuration.services.localstack.image -ne "${Project}-localstack:4.4.0") {
        throw "The isolated Compose image guard rejected LocalStack."
    }
}

function Get-ComposeServiceState {
    param(
        [string] $Docker,
        [string] $Project,
        [string] $Service,
        [switch] $IncludeStopped
    )

    $arguments = @("compose", "-f", $composePath, "-p", $Project, "--profile", "app", "ps")
    if ($IncludeStopped) {
        $arguments += "-a"
    }
    $arguments += @("-q", $Service)
    $containerId = ((& $Docker @arguments 2>$null) -join "").Trim()
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($containerId)) {
        return $null
    }
    $format = '{{.State.Status}}|{{if .State.Health}}{{.State.Health.Status}}{{end}}|{{.State.ExitCode}}'
    $value = ((& $Docker inspect --format $format $containerId 2>$null) -join "").Trim()
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($value)) {
        return $null
    }
    $parts = $value.Split('|')
    return [pscustomobject]@{
        Status = $parts[0]
        Health = $parts[1]
        ExitCode = [int] $parts[2]
    }
}

function Wait-IsolatedStack {
    param([string] $Docker, [string] $Project, [int] $TimeoutSeconds)

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        $ready = $true
        foreach ($service in @("postgres", "redis", "localstack", "keycloak", "api")) {
            $state = Get-ComposeServiceState -Docker $Docker -Project $Project -Service $service
            if (-not $state -or $state.Status -ne "running" -or $state.Health -ne "healthy") {
                $ready = $false
            }
        }
        $mailpit = Get-ComposeServiceState -Docker $Docker -Project $Project -Service "mailpit"
        if (-not $mailpit -or $mailpit.Status -ne "running") {
            $ready = $false
        }
        $configuration = Get-ComposeServiceState `
            -Docker $Docker `
            -Project $Project `
            -Service "keycloak-config" `
            -IncludeStopped
        if (-not $configuration -or
            $configuration.Status -ne "exited" -or
            $configuration.ExitCode -ne 0) {
            $ready = $false
        }
        if ($ready) {
            return
        }
        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $deadline)

    throw "The isolated local stack did not become healthy in time."
}

function Get-ProjectResources {
    param([string] $Docker, [string] $Kind, [string] $Project)

    $resources = switch ($Kind) {
        "container" {
            @(& $Docker ps -aq --filter "label=com.docker.compose.project=$Project" 2>$null)
        }
        "volume" {
            @(& $Docker volume ls -q --filter "label=com.docker.compose.project=$Project" 2>$null)
        }
        "network" {
            @(& $Docker network ls -q --filter "label=com.docker.compose.project=$Project" 2>$null)
        }
        default { throw "Unsupported Docker resource kind." }
    }
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to inspect isolated Docker resources."
    }
    return @($resources | Where-Object { $_ })
}

function Assert-ResourceOwnership {
    param(
        [string] $Docker,
        [string] $Kind,
        [string[]] $Identifiers,
        [string] $Project
    )

    foreach ($identifier in $Identifiers) {
        $format = switch ($Kind) {
            "container" { '{{index .Config.Labels "com.docker.compose.project"}}' }
            default { '{{index .Labels "com.docker.compose.project"}}' }
        }
        $owner = ((& $Docker inspect --type $Kind --format $format $identifier 2>$null) -join "").Trim()
        if ($LASTEXITCODE -ne 0 -or $owner -ne $Project) {
            throw "A Docker resource failed the isolated-project ownership guard."
        }
    }
}

function Remove-IsolatedImages {
    param([string] $Docker, [string] $Project)

    if ($Project -notmatch $projectPattern) {
        throw "Image cleanup refused an invalid isolated project name."
    }
    foreach ($image in @("${Project}-api:latest", "${Project}-localstack:4.4.0")) {
        $expectedImage = $image -eq "${Project}-api:latest" -or $image -eq "${Project}-localstack:4.4.0"
        if (-not $expectedImage) {
            throw "Cleanup refused an invalid isolated image name."
        }
        $imageIds = @(& $Docker image ls -q --filter "reference=$image" 2>$null | Where-Object { $_ })
        if ($LASTEXITCODE -ne 0) {
            throw "Unable to inspect isolated test images."
        }
        if ($imageIds.Count -eq 0) {
            continue
        }
        if ($imageIds.Count -ne 1) {
            throw "The isolated image lookup was ambiguous."
        }
        $tagJson = ((& $Docker image inspect --format '{{json .RepoTags}}' $image 2>$null) -join "").Trim()
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($tagJson)) {
            throw "Unable to verify an isolated test image."
        }
        $parsedTags = $tagJson | ConvertFrom-Json
        $tags = @($parsedTags)
        if ($image -notin $tags) {
            throw "An isolated image failed the exact-tag ownership guard."
        }
        & $Docker image rm $image 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "An isolated test image could not be removed."
        }
        $remaining = @(& $Docker image ls -q --filter "reference=$image" 2>$null | Where-Object { $_ })
        if ($LASTEXITCODE -ne 0 -or $remaining.Count -ne 0) {
            throw "An isolated test image still exists after cleanup."
        }
    }
}

function Get-StaleIsolatedProjectNames {
    param([string] $Docker)

    $projects = [System.Collections.Generic.HashSet[string]]::new()
    $queries = @(
        @("ps", "-a", "--filter", "label=com.docker.compose.project", "--format", "{{json .Labels}}"),
        @("volume", "ls", "--filter", "label=com.docker.compose.project", "--format", "{{json .Labels}}"),
        @("network", "ls", "--filter", "label=com.docker.compose.project", "--format", "{{json .Labels}}")
    )
    foreach ($query in $queries) {
        $rows = @(& $Docker @query 2>$null)
        if ($LASTEXITCODE -ne 0) {
            throw "Unable to inspect stale isolated Docker projects."
        }
        foreach ($row in $rows) {
            $match = [Regex]::Match($row, '(?:^"|,)com\.docker\.compose\.project=(kelimio-e2e-[0-9a-f]{12})(?:,|"$)')
            if ($match.Success) {
                [void] $projects.Add($match.Groups[1].Value)
            }
        }
    }

    $images = @(& $Docker image ls --format '{{.Repository}}:{{.Tag}}' 2>$null)
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to inspect stale isolated Docker images."
    }
    foreach ($image in $images) {
        $match = [Regex]::Match($image, '^(kelimio-e2e-[0-9a-f]{12})-(?:api:latest|localstack:4\.4\.0)$')
        if ($match.Success) {
            [void] $projects.Add($match.Groups[1].Value)
        }
    }
    return @($projects | Sort-Object)
}

function Remove-StaleIsolatedProjects {
    param([string] $Docker)

    foreach ($staleProject in @(Get-StaleIsolatedProjectNames -Docker $Docker)) {
        if ($staleProject -notmatch $projectPattern) {
            throw "Stale cleanup refused an invalid isolated project name."
        }
        $containers = Get-ProjectResources -Docker $Docker -Kind "container" -Project $staleProject
        Assert-ResourceOwnership -Docker $Docker -Kind "container" -Identifiers $containers -Project $staleProject
        foreach ($container in $containers) {
            $running = ((& $Docker inspect --type container --format '{{.State.Running}}' $container 2>$null) -join "").Trim()
            if ($LASTEXITCODE -ne 0 -or $running -notin @("true", "false")) {
                throw "Unable to verify a stale isolated container state."
            }
            if ($running -eq "true") {
                throw "A running isolated project exists; cleanup refused to interrupt it."
            }
        }
        if ($containers.Count -gt 0) {
            & $Docker rm @containers 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "Unable to remove stale isolated containers."
            }
        }

        $volumes = Get-ProjectResources -Docker $Docker -Kind "volume" -Project $staleProject
        Assert-ResourceOwnership -Docker $Docker -Kind "volume" -Identifiers $volumes -Project $staleProject
        if ($volumes.Count -gt 0) {
            & $Docker volume rm @volumes 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "Unable to remove stale isolated volumes."
            }
        }

        $networks = Get-ProjectResources -Docker $Docker -Kind "network" -Project $staleProject
        Assert-ResourceOwnership -Docker $Docker -Kind "network" -Identifiers $networks -Project $staleProject
        if ($networks.Count -gt 0) {
            & $Docker network rm @networks 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "Unable to remove stale isolated networks."
            }
        }
        Remove-IsolatedImages -Docker $Docker -Project $staleProject

        if ((Get-ProjectResources -Docker $Docker -Kind "container" -Project $staleProject).Count -ne 0 -or
            (Get-ProjectResources -Docker $Docker -Kind "volume" -Project $staleProject).Count -ne 0 -or
            (Get-ProjectResources -Docker $Docker -Kind "network" -Project $staleProject).Count -ne 0) {
            throw "Stale isolated Docker cleanup did not reach zero resources."
        }
    }
}

function Remove-IsolatedProject {
    param(
        [string] $Docker,
        [string] $Project,
        [hashtable] $Ports
    )

    if ($Project -notmatch $projectPattern) {
        throw "Cleanup refused an invalid isolated project name."
    }
    $configuration = Get-ComposeConfiguration -Docker $Docker -Project $Project
    Assert-IsolatedComposeConfiguration -Configuration $configuration -Project $Project -Ports $Ports

    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        & $Docker compose -f $composePath -p $Project --profile app down --volumes --remove-orphans 2>&1 | Out-Null
    } finally {
        $ErrorActionPreference = $previousPreference
    }

    $containers = Get-ProjectResources -Docker $Docker -Kind "container" -Project $Project
    if ($containers.Count -gt 0) {
        Assert-ResourceOwnership -Docker $Docker -Kind "container" -Identifiers $containers -Project $Project
        & $Docker rm -f @containers 2>&1 | Out-Null
    }
    $volumes = Get-ProjectResources -Docker $Docker -Kind "volume" -Project $Project
    if ($volumes.Count -gt 0) {
        Assert-ResourceOwnership -Docker $Docker -Kind "volume" -Identifiers $volumes -Project $Project
        & $Docker volume rm @volumes 2>&1 | Out-Null
    }
    $networks = Get-ProjectResources -Docker $Docker -Kind "network" -Project $Project
    if ($networks.Count -gt 0) {
        Assert-ResourceOwnership -Docker $Docker -Kind "network" -Identifiers $networks -Project $Project
        & $Docker network rm @networks 2>&1 | Out-Null
    }

    if ((Get-ProjectResources -Docker $Docker -Kind "container" -Project $Project).Count -ne 0 -or
        (Get-ProjectResources -Docker $Docker -Kind "volume" -Project $Project).Count -ne 0 -or
        (Get-ProjectResources -Docker $Docker -Kind "network" -Project $Project).Count -ne 0) {
        throw "Isolated Docker cleanup did not reach zero resources."
    }

    Remove-IsolatedImages -Docker $Docker -Project $Project
}

$dockerCommand = Get-Command docker -ErrorAction Stop
$flutterCommand = Get-Command flutter -ErrorAction Stop
$adb = Resolve-Adb
$mutex = [System.Threading.Mutex]::new($false, "Local\KelimioRealStackE2E")
$mutexHeld = $false
$project = $null
$addedReversePorts = [System.Collections.Generic.List[int]]::new()
$previousEnvironment = @{}
$normalContainerIds = @()
$normalReverseMappings = @()
$normalSnapshotTaken = $false
$reverseSnapshotTaken = $false
$failure = $null
$cleanupFailure = $null
$configurationValidated = $false
$deviceReady = $false
$normalAppInstalled = $false
$normalAppSnapshotTaken = $false
$stage = "runner initialization"

foreach ($name in $environmentNames) {
    $previousEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, "Process")
}

try {
    try {
        $mutexHeld = $mutex.WaitOne(0)
    } catch [System.Threading.AbandonedMutexException] {
        $mutexHeld = $true
    }
    if (-not $mutexHeld) {
        throw "Another Kelimio real-stack E2E run is already active."
    }

    $stage = "stale isolated Docker preflight"
    Remove-StaleIsolatedProjects -Docker $dockerCommand.Source

    $deviceState = @(& $adb devices | Where-Object { $_ -match "^$([Regex]::Escape($DeviceId))\s+device$" })
    if ($deviceState.Count -ne 1) {
        throw "The requested Android emulator is not ready. Start it with scripts/android-emulator.ps1."
    }
    $deviceReady = $true

    $stage = "isolated Android package preflight"
    Remove-E2eAndroidApplication -Adb $adb -Serial $DeviceId
    $normalAppInstalled = Test-AndroidPackageInstalled `
        -Adb $adb `
        -Serial $DeviceId `
        -PackageName "com.kelimio.app"
    $normalAppSnapshotTaken = $true

    $normalContainerIds = @(& $dockerCommand.Source compose -f $composePath --profile app ps -q 2>$null | Sort-Object)
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to snapshot the normal Compose project."
    }
    $normalSnapshotTaken = $true
    $normalReverseMappings = Get-AdbReverseMappings -Adb $adb -Serial $DeviceId
    $reverseSnapshotTaken = $true
    $reservedPorts = [System.Collections.Generic.HashSet[int]]::new()
    foreach ($mapping in $normalReverseMappings) {
        foreach ($match in [Regex]::Matches($mapping, 'tcp:(\d+)')) {
            [void] $reservedPorts.Add([int] $match.Groups[1].Value)
        }
    }

    $project = "kelimio-e2e-$(New-RandomHex -ByteCount 6)"
    if ($project -notmatch $projectPattern) {
        throw "Generated isolated project name failed validation."
    }
    $ports = @{
        Postgres = Get-AvailableLoopbackPort $reservedPorts
        Redis = Get-AvailableLoopbackPort $reservedPorts
        LocalStack = Get-AvailableLoopbackPort $reservedPorts
        Keycloak = Get-AvailableLoopbackPort $reservedPorts
        MailpitSmtp = Get-AvailableLoopbackPort $reservedPorts
        MailpitHttp = Get-AvailableLoopbackPort $reservedPorts
        Api = Get-AvailableLoopbackPort $reservedPorts
    }

    $environmentValues = @{
        KELIMIO_LOCAL_DB_PASSWORD = New-RandomSecret
        KELIMIO_LOCAL_KEYCLOAK_ADMIN = "e2e-admin-$(New-RandomHex -ByteCount 6)"
        KELIMIO_LOCAL_KEYCLOAK_PASSWORD = New-RandomSecret
        KELIMIO_LOCAL_POSTGRES_HOST_PORT = $ports.Postgres.ToString()
        KELIMIO_LOCAL_REDIS_HOST_PORT = $ports.Redis.ToString()
        KELIMIO_LOCAL_LOCALSTACK_HOST_PORT = $ports.LocalStack.ToString()
        KELIMIO_LOCALSTACK_IMAGE = "${project}-localstack:4.4.0"
        KELIMIO_LOCAL_KEYCLOAK_HOST_PORT = $ports.Keycloak.ToString()
        KELIMIO_LOCAL_MAILPIT_SMTP_HOST_PORT = $ports.MailpitSmtp.ToString()
        KELIMIO_LOCAL_MAILPIT_HTTP_HOST_PORT = $ports.MailpitHttp.ToString()
        KELIMIO_LOCAL_API_HOST_PORT = $ports.Api.ToString()
        KELIMIO_LOCAL_KEYCLOAK_BASE_URL = "http://localhost:$($ports.Keycloak)"
        KELIMIO_LOCAL_OIDC_ISSUER = "http://localhost:$($ports.Keycloak)/realms/kelimio"
        KELIMIO_LOCAL_RESTART_POLICY = "no"
    }
    foreach ($entry in $environmentValues.GetEnumerator()) {
        [Environment]::SetEnvironmentVariable($entry.Key, [string] $entry.Value, "Process")
    }

    $stage = "isolated Compose guard"
    $configuration = Get-ComposeConfiguration -Docker $dockerCommand.Source -Project $project
    Assert-IsolatedComposeConfiguration -Configuration $configuration -Project $project -Ports $ports
    $configurationValidated = $true

    $stage = "isolated service startup"
    Write-Host "Starting isolated Kelimio services without touching the normal development stack..."
    & $dockerCommand.Source compose -f $composePath -p $project --profile app up -d --build api
    if ($LASTEXITCODE -ne 0) {
        throw "Isolated Compose startup failed."
    }
    Wait-IsolatedStack -Docker $dockerCommand.Source -Project $project -TimeoutSeconds $StartupTimeoutSeconds

    $stage = "isolated service readiness"
    $apiHealth = Invoke-RestMethod `
        -Uri "http://localhost:$($ports.Api)/actuator/health/readiness" `
        -TimeoutSec 10
    if ($apiHealth.status -ne "UP") {
        throw "The isolated API readiness probe failed."
    }
    $discovery = Invoke-RestMethod `
        -Uri "http://localhost:$($ports.Keycloak)/realms/kelimio/.well-known/openid-configuration" `
        -TimeoutSec 10
    if ($discovery.issuer -ne $environmentValues.KELIMIO_LOCAL_OIDC_ISSUER) {
        throw "The isolated identity issuer did not match its advertised value."
    }
    [void] (Invoke-RestMethod -Uri "http://localhost:$($ports.MailpitHttp)/api/v1/info" -TimeoutSec 10)

    $stage = "Android reverse-port setup"
    foreach ($port in @($ports.Api, $ports.Keycloak, $ports.MailpitHttp)) {
        $currentMappings = Get-AdbReverseMappings -Adb $adb -Serial $DeviceId
        if ($currentMappings -match "tcp:$port(?:\s|$)") {
            throw "An isolated Android reverse port was already in use."
        }
        & $adb -s $DeviceId reverse "tcp:$port" "tcp:$port" | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Unable to add an isolated Android reverse-port mapping."
        }
        $addedReversePorts.Add($port)
    }

    $stage = "real Android registration-to-progress test"
    Write-Host "Running real Keycloak, Mailpit, backend, Drift, and Flutter UI acceptance flow..."
    Push-Location $mobilePath
    try {
        & $flutterCommand.Source test $testPath `
            -d $DeviceId `
            --flavor e2e `
            --no-uninstall `
            "--dart-define=KELIMIO_API_BASE_URL=http://localhost:$($ports.Api)" `
            "--dart-define=KELIMIO_OIDC_ISSUER=$($environmentValues.KELIMIO_LOCAL_OIDC_ISSUER)" `
            "--dart-define=KELIMIO_OIDC_CLIENT_ID=kelimio-mobile" `
            "--dart-define=KELIMIO_LOCAL_DEVELOPMENT_TOOLS=true" `
            "--dart-define=KELIMIO_REAL_E2E_MAILPIT_BASE_URL=http://localhost:$($ports.MailpitHttp)" `
            "--dart-define=KELIMIO_REAL_STACK_E2E=true"
        if ($LASTEXITCODE -ne 0) {
            throw "The real Android acceptance test failed."
        }
    } finally {
        Pop-Location
    }

} catch {
    $failure = [System.Exception]::new("Local Android E2E failed during $stage. Sensitive values were suppressed.")
} finally {
    foreach ($port in $addedReversePorts) {
        try {
            & $adb -s $DeviceId reverse --remove "tcp:$port" 2>$null | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "ADB reverse removal failed."
            }
        } catch {
            $cleanupFailure = [System.Exception]::new("An isolated Android reverse-port mapping could not be removed.")
        }
    }

    if ($deviceReady) {
        try {
            Remove-E2eAndroidApplication -Adb $adb -Serial $DeviceId
        } catch {
            $cleanupFailure = [System.Exception]::new("The isolated Android test package could not be removed.")
        }
    }

    if ($project -and $configurationValidated) {
        try {
            Remove-IsolatedProject -Docker $dockerCommand.Source -Project $project -Ports $ports
        } catch {
            $cleanupFailure = [System.Exception]::new("The isolated Docker project did not clean up completely.")
        }
    }

    try {
        if ($normalSnapshotTaken) {
            $currentNormalIds = @(& $dockerCommand.Source compose -f $composePath --profile app ps -q 2>$null | Sort-Object)
            if ($LASTEXITCODE -ne 0) {
                throw "Unable to verify the normal Compose project."
            }
            if (($normalContainerIds -join "`n") -ne ($currentNormalIds -join "`n")) {
                throw "The normal Compose project changed during the isolated test."
            }
        }
        if ($reverseSnapshotTaken) {
            $initialMappings = @($normalReverseMappings | Sort-Object)
            $currentMappings = @(Get-AdbReverseMappings -Adb $adb -Serial $DeviceId | Sort-Object)
            if (($initialMappings -join "`n") -ne ($currentMappings -join "`n")) {
                throw "Android reverse-port mappings changed during the isolated test."
            }
        }
        if ($normalAppSnapshotTaken) {
            $currentNormalAppInstalled = Test-AndroidPackageInstalled `
                -Adb $adb `
                -Serial $DeviceId `
                -PackageName "com.kelimio.app"
            if ($currentNormalAppInstalled -ne $normalAppInstalled) {
                throw "The normal Android application installation changed during the isolated test."
            }
        }
    } catch {
        $cleanupFailure = [System.Exception]::new("Normal development-state preservation could not be verified.")
    }

    foreach ($name in $environmentNames) {
        [Environment]::SetEnvironmentVariable($name, $previousEnvironment[$name], "Process")
    }
    if ($mutexHeld) {
        $mutex.ReleaseMutex()
    }
    $mutex.Dispose()
}

if ($cleanupFailure) {
    throw $cleanupFailure
}
if ($failure) {
    throw $failure
}

Write-Host "Real local Android registration-to-progress acceptance passed."
