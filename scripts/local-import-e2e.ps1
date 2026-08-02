[CmdletBinding()]
param(
    [string] $WorkbookPath = "",
    [ValidateRange(180, 1200)]
    [int] $StartupTimeoutSeconds = 600,
    [ValidateRange(60, 900)]
    [int] $ProcessingTimeoutSeconds = 420
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Net.Http

$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$composePath = Join-Path $repositoryRoot "compose.yaml"
if ([string]::IsNullOrWhiteSpace($WorkbookPath)) {
    $WorkbookPath = Join-Path $repositoryRoot `
        "backend/src/test/resources/import/valid/kurs_excel_plani_v3_test_numarali.xlsx"
}
$WorkbookPath = [System.IO.Path]::GetFullPath($WorkbookPath)
if (-not (Test-Path -LiteralPath $WorkbookPath -PathType Leaf)) {
    throw "The reviewed workbook fixture is unavailable."
}

$projectPattern = '^kelimio-import-e2e-[0-9a-f]{12}$'
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
    "KELIMIO_LOCAL_OTEL_GRPC_HOST_PORT",
    "KELIMIO_LOCAL_OTEL_HTTP_HOST_PORT",
    "KELIMIO_LOCAL_OTEL_METRICS_HOST_PORT",
    "KELIMIO_LOCAL_API_HOST_PORT",
    "KELIMIO_LOCAL_KEYCLOAK_BASE_URL",
    "KELIMIO_LOCAL_OIDC_ISSUER",
    "KELIMIO_MATCHING_REPLAY_ACTIVE_KEY_VERSION",
    "KELIMIO_MATCHING_REPLAY_KEYS",
    "KELIMIO_LOCAL_IMPORT_CURSOR_HMAC_KEY",
    "KELIMIO_BUILD_REVISION",
    "KELIMIO_LOCAL_RESTART_POLICY"
)

function New-RandomBytes {
    param([ValidateRange(1, 64)][int] $Count)

    $bytes = New-Object byte[] $Count
    $generator = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $generator.GetBytes($bytes)
        return $bytes
    } finally {
        $generator.Dispose()
    }
}

function New-RandomHex {
    param([ValidateRange(1, 64)][int] $Count)

    return ((New-RandomBytes $Count) | ForEach-Object { $_.ToString("x2") }) -join ""
}

function New-RandomBase64Key {
    $bytes = New-RandomBytes 32
    try {
        return [Convert]::ToBase64String($bytes)
    } finally {
        [Array]::Clear($bytes, 0, $bytes.Length)
    }
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
    throw "Unable to reserve an isolated loopback port."
}

function Invoke-DockerCapture {
    param([Parameter(Mandatory = $true)][string[]] $Arguments)

    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $output = @(& $script:docker @Arguments 2>$null)
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
    }
    if ($exitCode -ne 0) {
        throw "A guarded Docker inspection failed."
    }
    return ($output -join "`n").Trim()
}

function Invoke-DockerQuiet {
    param([Parameter(Mandatory = $true)][string[]] $Arguments)

    # Windows PowerShell 5.1 wraps ordinary native stderr progress as
    # ErrorRecord objects. Compose writes build/start/stop progress to stderr
    # even on success, so keep it non-terminating and rely on the native exit
    # code instead.
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        & $script:docker @Arguments 2>&1 | Out-Null
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
    }
    if ($exitCode -ne 0) {
        throw "A guarded Docker operation failed."
    }
}

function Get-ComposeArguments {
    param([Parameter(Mandatory = $true)][string[]] $Tail)

    return @("compose", "-f", $composePath, "-p", $script:project, "--profile", "app") + $Tail
}

function Get-ComposeConfiguration {
    $json = Invoke-DockerCapture (Get-ComposeArguments @("config", "--format", "json"))
    if ([string]::IsNullOrWhiteSpace($json)) {
        throw "The isolated Compose configuration is empty."
    }
    return $json | ConvertFrom-Json
}

function Get-NetworkNames {
    param([object] $Service)

    if ($null -eq $Service.networks) { return @() }
    return @($Service.networks.PSObject.Properties.Name)
}

function Assert-IsolatedComposeConfiguration {
    param([object] $Configuration)

    if ($script:project -notmatch $projectPattern -or $Configuration.name -ne $script:project) {
        throw "The Compose project failed its isolated-name guard."
    }
    foreach ($property in $Configuration.volumes.PSObject.Properties) {
        $volume = $property.Value
        if ($volume.external -eq $true -or -not $volume.name.StartsWith("$($script:project)_")) {
            throw "The Compose project contains a non-isolated volume."
        }
    }
    foreach ($property in $Configuration.networks.PSObject.Properties) {
        $network = $property.Value
        if ($network.external -eq $true -or -not $network.name.StartsWith("$($script:project)_")) {
            throw "The Compose project contains a non-isolated network."
        }
    }
    if ($Configuration.networks.'scanner-only'.internal -ne $true) {
        throw "The malware scanner network must be internal."
    }
    $apiNetworks = Get-NetworkNames $Configuration.services.api
    $workerNetworks = Get-NetworkNames $Configuration.services.'import-worker'
    $scannerNetworks = Get-NetworkNames $Configuration.services.clamav
    if (@($apiNetworks | Where-Object { $_ -in $scannerNetworks }).Count -ne 0) {
        throw "The API unexpectedly shares a network with the malware scanner."
    }
    if ("scanner-only" -notin $workerNetworks -or "scanner-only" -notin $scannerNetworks) {
        throw "The import worker and scanner do not share their private network."
    }
    if ($null -ne $Configuration.services.clamav.ports -and
        @($Configuration.services.clamav.ports).Count -ne 0) {
        throw "ClamAV unexpectedly publishes a host port."
    }
    $workerEnvironment = $Configuration.services.'import-worker'.environment
    foreach ($secretName in @(
        "KELIMIO_MATCHING_REPLAY_ACTIVE_KEY_VERSION",
        "KELIMIO_MATCHING_REPLAY_KEYS",
        "KELIMIO_IMPORT_CURSOR_HMAC_KEY",
        "KELIMIO_OIDC_ISSUER",
        "KELIMIO_OIDC_JWK_SET_URI",
        "KELIMIO_OIDC_AUDIENCE"
    )) {
        if ($null -ne $workerEnvironment.PSObject.Properties[$secretName]) {
            throw "The import worker unexpectedly receives an API-only secret or identity setting."
        }
    }
    if ($workerEnvironment.SPRING_FLYWAY_ENABLED -ne "false") {
        throw "The import worker must not run schema migrations."
    }
}

function Get-ServiceState {
    param([string] $Service, [switch] $IncludeStopped)

    $tail = @("ps")
    if ($IncludeStopped) { $tail += "-a" }
    $tail += @("-q", $Service)
    $containerId = Invoke-DockerCapture (Get-ComposeArguments $tail)
    if ([string]::IsNullOrWhiteSpace($containerId)) { return $null }
    $value = Invoke-DockerCapture @(
        "inspect",
        "--format",
        '{{.State.Status}}|{{if .State.Health}}{{.State.Health.Status}}{{end}}|{{.State.ExitCode}}',
        $containerId
    )
    $parts = $value.Split('|')
    return [pscustomobject]@{
        Status = $parts[0]
        Health = $parts[1]
        ExitCode = [int] $parts[2]
    }
}

function Wait-IsolatedStack {
    $deadline = (Get-Date).AddSeconds($StartupTimeoutSeconds)
    do {
        $ready = $true
        foreach ($service in @("postgres", "redis", "localstack", "keycloak", "clamav", "api")) {
            $state = Get-ServiceState $service
            if (-not $state -or $state.Status -ne "running" -or $state.Health -ne "healthy") {
                $ready = $false
            }
        }
        foreach ($service in @("mailpit", "otel-collector", "import-worker")) {
            $state = Get-ServiceState $service
            if (-not $state -or $state.Status -ne "running") { $ready = $false }
        }
        $configuration = Get-ServiceState "keycloak-config" -IncludeStopped
        if (-not $configuration -or $configuration.Status -ne "exited" -or $configuration.ExitCode -ne 0) {
            $ready = $false
        }
        if ($ready) { return }
        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $deadline)
    throw "The isolated local import stack did not become healthy in time."
}

function Get-HashPair {
    param([byte[]] $Bytes)

    $algorithm = [System.Security.Cryptography.SHA256]::Create()
    try {
        $digest = $algorithm.ComputeHash($Bytes)
        return [pscustomobject]@{
            Hex = (($digest | ForEach-Object { $_.ToString("x2") }) -join "")
            Base64 = [Convert]::ToBase64String($digest)
        }
    } finally {
        $algorithm.Dispose()
    }
}

function Send-Json {
    param(
        [string] $Method,
        [string] $Uri,
        [string] $Token,
        [object] $Body,
        [string] $IdempotencyKey,
        [int[]] $ExpectedStatus = @(200),
        [string] $ClientCapabilities = ""
    )

    $request = [System.Net.Http.HttpRequestMessage]::new(
        [System.Net.Http.HttpMethod]::new($Method),
        $Uri
    )
    try {
        if (-not [string]::IsNullOrWhiteSpace($Token)) {
            $request.Headers.Authorization = [System.Net.Http.Headers.AuthenticationHeaderValue]::new("Bearer", $Token)
        }
        if (-not [string]::IsNullOrWhiteSpace($IdempotencyKey)) {
            [void] $request.Headers.TryAddWithoutValidation("Idempotency-Key", $IdempotencyKey)
        }
        if (-not [string]::IsNullOrWhiteSpace($ClientCapabilities)) {
            [void] $request.Headers.TryAddWithoutValidation(
                "X-Kelimio-Client-Capabilities",
                $ClientCapabilities
            )
        }
        if ($null -ne $Body) {
            $json = $Body | ConvertTo-Json -Depth 20 -Compress
            $request.Content = [System.Net.Http.StringContent]::new(
                $json,
                [System.Text.Encoding]::UTF8,
                "application/json"
            )
        }
        $response = $script:http.SendAsync($request).GetAwaiter().GetResult()
        try {
            $status = [int] $response.StatusCode
            $raw = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
            if (($Uri.StartsWith("$($script:apiBase)/v1/courses/imports", [StringComparison]::Ordinal) -or
                $Uri.Contains("/releases/")) -and
                ($null -eq $response.Headers.CacheControl -or -not $response.Headers.CacheControl.NoStore)) {
                throw "A sensitive owner-scoped response omitted Cache-Control: no-store."
            }
            if ($status -notin $ExpectedStatus) {
                $safePath = ([Uri] $Uri).AbsolutePath -replace `
                    '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}', `
                    '{id}'
                $problem = try { $raw | ConvertFrom-Json } catch { $null }
                $requestId = if ($problem.requestId -match `
                    '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') {
                    $problem.requestId
                } else { "unavailable" }
                throw "Unexpected HTTP $status for $Method $safePath (requestId=$requestId)."
            }
            $parsed = if ([string]::IsNullOrWhiteSpace($raw)) { $null } else { $raw | ConvertFrom-Json }
            return [pscustomobject]@{ Status = $status; Body = $parsed; Raw = $raw }
        } finally {
            $response.Dispose()
        }
    } finally {
        $request.Dispose()
    }
}

function Get-AccessToken {
    param([string] $Username, [string] $Password)

    $pairs = [System.Collections.Generic.List[System.Collections.Generic.KeyValuePair[string,string]]]::new()
    $pairs.Add([System.Collections.Generic.KeyValuePair[string,string]]::new("grant_type", "password"))
    $pairs.Add([System.Collections.Generic.KeyValuePair[string,string]]::new("client_id", "kelimio-mobile"))
    $pairs.Add([System.Collections.Generic.KeyValuePair[string,string]]::new("username", $Username))
    $pairs.Add([System.Collections.Generic.KeyValuePair[string,string]]::new("password", $Password))
    $request = [System.Net.Http.HttpRequestMessage]::new(
        [System.Net.Http.HttpMethod]::Post,
        "$($script:keycloakBase)/realms/kelimio/protocol/openid-connect/token"
    )
    $request.Content = [System.Net.Http.FormUrlEncodedContent]::new($pairs)
    try {
        $response = $script:http.SendAsync($request).GetAwaiter().GetResult()
        try {
            $raw = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
            if ([int] $response.StatusCode -ne 200) {
                $tokenError = try { $raw | ConvertFrom-Json } catch { $null }
                $safeCode = if ($tokenError.error -match '^[a-z_]{1,64}$') {
                    $tokenError.error
                } else { "unknown" }
                $safeReason = if ($tokenError.error_description -in @(
                    "Account is not fully set up",
                    "Invalid user credentials"
                )) { $tokenError.error_description } else { "provider-rejected" }
                throw "The isolated token exchange failed with HTTP $([int] $response.StatusCode), code $safeCode, reason $safeReason."
            }
            $payload = $raw | ConvertFrom-Json
            if ([string]::IsNullOrWhiteSpace($payload.access_token)) {
                throw "The isolated token response was incomplete."
            }
            return $payload.access_token
        } finally {
            $response.Dispose()
        }
    } finally {
        $request.Dispose()
    }
}

function New-CompletedUser {
    param([string] $Label)

    $username = "$Label-$(New-RandomHex 6)"
    $password = "Aa!$(New-RandomHex 18)"
    $email = "$username@integration.invalid"
    $userId = Invoke-DockerCapture (Get-ComposeArguments @(
        "exec", "-T", "keycloak", "/opt/keycloak/bin/kcadm.sh", "create", "users",
        "--config", "/tmp/kelimio-import-e2e.config", "-r", "kelimio", "-i",
        "-s", "username=$username", "-s", "email=$email",
        "-s", "firstName=Import", "-s", "lastName=Test",
        "-s", "enabled=true", "-s", "emailVerified=true", "-s", "requiredActions=[]"
    ))
    if ($userId -notmatch '^[0-9a-fA-F-]{36}$') { throw "The isolated user identifier is invalid." }
    Invoke-DockerQuiet (Get-ComposeArguments @(
        "exec", "-T", "keycloak", "/opt/keycloak/bin/kcadm.sh", "set-password",
        "--config", "/tmp/kelimio-import-e2e.config", "-r", "kelimio",
        "--userid", $userId, "--new-password", $password
    ))
    $token = Get-AccessToken $username $password
    [void] (Send-Json "GET" "$($script:apiBase)/v1/me" $token $null "" @(200))
    $profile = Send-Json "POST" "$($script:apiBase)/v1/me/profile-setup" $token @{
        displayName = "Import Test"
        appLocale = "tr"
        activeTargetLanguage = "tr"
        preferredSupportLanguage = "en"
        timeZone = "Europe/Istanbul"
    } ([guid]::NewGuid().ToString()) @(200)
    if ($profile.Body.profileSetupStatus -ne "COMPLETE") {
        throw "The isolated user profile did not complete."
    }
    return $token
}

function Send-UploadPart {
    param([string] $Uri, [byte[]] $Bytes, [string] $Checksum)

    $request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Put, $Uri)
    $request.Content = [System.Net.Http.ByteArrayContent]::new($Bytes)
    $request.Content.Headers.ContentLength = $Bytes.Length
    [void] $request.Headers.TryAddWithoutValidation("x-amz-checksum-sha256", $Checksum)
    try {
        $response = $script:http.SendAsync($request).GetAwaiter().GetResult()
        try {
            if ([int] $response.StatusCode -notin @(200, 201)) {
                throw "The isolated presigned upload failed."
            }
            $etag = $response.Headers.ETag.Tag
            if ([string]::IsNullOrWhiteSpace($etag) -or $etag -notmatch '^[!-~]{1,256}$') {
                throw "The object store returned an invalid ETag."
            }
            return $etag
        } finally {
            $response.Dispose()
        }
    } finally {
        $request.Dispose()
    }
}

function Start-Import {
    param([string] $Token, [string] $FileName, [byte[]] $Bytes)

    if ($Bytes.Length -lt 1 -or $Bytes.Length -gt 5242880) {
        throw "This acceptance helper intentionally supports one bounded multipart part."
    }
    $hash = Get-HashPair $Bytes
    $create = Send-Json "POST" "$($script:apiBase)/v1/courses/imports" $Token @{
        originalFileName = $FileName
        declaredMediaType = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        fileSizeBytes = $Bytes.Length
        sourceSha256 = $hash.Hex
        parts = @(@{ partNumber = 1; sizeBytes = $Bytes.Length; sha256 = $hash.Base64 })
    } ([guid]::NewGuid().ToString()) @(201)
    $importId = $create.Body.import.id
    $signedPart = @($create.Body.upload.parts)[0]
    if ([string]::IsNullOrWhiteSpace($importId) -or $signedPart.requiredHeaders.contentLength -ne "$($Bytes.Length)" -or
        $signedPart.requiredHeaders.sha256 -ne $hash.Base64) {
        throw "The upload session did not bind the declared part."
    }
    $signedExpiry = [DateTimeOffset]::Parse($create.Body.upload.expiresAt)
    $sessionExpiry = [DateTimeOffset]::Parse($create.Body.import.uploadExpiresAt)
    $expiryCheckTime = [DateTimeOffset]::UtcNow
    if ($signedExpiry -gt $sessionExpiry -or $signedExpiry -le $expiryCheckTime) {
        throw "The signed upload expiry is inconsistent (signed=$($signedExpiry.ToString('O')), session=$($sessionExpiry.ToString('O')), checked=$($expiryCheckTime.ToString('O')))."
    }
    $etag = Send-UploadPart $signedPart.url $Bytes $hash.Base64
    $complete = Send-Json "POST" "$($script:apiBase)/v1/courses/imports/$importId/complete" $Token @{
        sourceSha256 = $hash.Hex
        parts = @(@{ partNumber = 1; eTag = $etag; sha256 = $hash.Base64 })
    } ([guid]::NewGuid().ToString()) @(202)
    if ($complete.Body.id -ne $importId -or $complete.Body.status -ne "QUEUED") {
        throw "The upload completion was not queued exactly once."
    }
    return $importId
}

function Wait-ImportStatus {
    param([string] $Token, [string] $ImportId, [string] $ExpectedStatus)

    $deadline = (Get-Date).AddSeconds($ProcessingTimeoutSeconds)
    $terminal = @("PREVIEW_READY", "VALIDATION_FAILED", "MALWARE_REJECTED", "PROCESSING_FAILED", "EXPIRED", "APPROVED", "COMMITTED")
    do {
        $response = Send-Json "GET" "$($script:apiBase)/v1/courses/imports/$ImportId" $Token $null "" @(200)
        if ($response.Raw -match 'quarantineBucket|archiveBucket|objectKey|uploadId|versionId|clamav|scannerEngine') {
            throw "An import status response exposed an internal storage or scanner field."
        }
        if ($response.Body.status -eq $ExpectedStatus) { return $response.Body }
        if ($response.Body.status -in $terminal) {
            throw "The import reached an unexpected terminal state."
        }
        Start-Sleep -Milliseconds 500
    } while ((Get-Date) -lt $deadline)
    throw "The import did not reach its expected terminal state in time."
}

function Invoke-DatabaseScalar {
    param([string] $Query)

    $value = Invoke-DockerCapture (Get-ComposeArguments @(
        "exec", "-T", "postgres", "psql", "-U", "kelimio", "-d", "kelimio",
        "--no-psqlrc", "--tuples-only", "--no-align", "--command", $Query
    ))
    return $value.Trim()
}

function Assert-LocalInfrastructure {
    $flyway = Invoke-DatabaseScalar `
        "select version from flyway_schema_history where success and version is not null order by installed_rank desc limit 1"
    if ($flyway -ne "13") { throw "The isolated database did not reach Flyway V13." }
    foreach ($bucket in @("kelimio-local-import-quarantine", "kelimio-local-import-archive")) {
        $status = Invoke-DockerCapture (Get-ComposeArguments @(
            "exec", "-T", "localstack", "awslocal", "s3api", "get-bucket-versioning",
            "--bucket", $bucket, "--query", "Status", "--output", "text"
        ))
        if ($status -ne "Enabled") { throw "An import bucket is not versioned." }
    }
    $queueUrl = Invoke-DockerCapture (Get-ComposeArguments @(
        "exec", "-T", "localstack", "awslocal", "sqs", "get-queue-url",
        "--queue-name", "kelimio-import", "--query", "QueueUrl", "--output", "text"
    ))
    $attributes = Invoke-DockerCapture (Get-ComposeArguments @(
        "exec", "-T", "localstack", "awslocal", "sqs", "get-queue-attributes",
        "--queue-url", $queueUrl, "--attribute-names", "VisibilityTimeout", "RedrivePolicy", "--output", "json"
    )) | ConvertFrom-Json
    if ($attributes.Attributes.VisibilityTimeout -ne "480" -or
        (($attributes.Attributes.RedrivePolicy | ConvertFrom-Json).maxReceiveCount) -ne "5") {
        throw "The import queue safety attributes are inconsistent."
    }
}

function Wait-QueueDrained {
    param([string] $QueueName)

    $queueUrl = Invoke-DockerCapture (Get-ComposeArguments @(
        "exec", "-T", "localstack", "awslocal", "sqs", "get-queue-url",
        "--queue-name", $QueueName, "--query", "QueueUrl", "--output", "text"
    ))
    $deadline = (Get-Date).AddSeconds(30)
    do {
        $attributes = Invoke-DockerCapture (Get-ComposeArguments @(
            "exec", "-T", "localstack", "awslocal", "sqs", "get-queue-attributes",
            "--queue-url", $queueUrl, "--attribute-names", "ApproximateNumberOfMessages",
            "ApproximateNumberOfMessagesNotVisible", "--output", "json"
        )) | ConvertFrom-Json
        if ($attributes.Attributes.ApproximateNumberOfMessages -eq "0" -and
            $attributes.Attributes.ApproximateNumberOfMessagesNotVisible -eq "0") {
            return
        }
        Start-Sleep -Milliseconds 500
    } while ((Get-Date) -lt $deadline)
    throw "An isolated import queue did not drain in time."
}

$dockerCommand = Get-Command docker -ErrorAction Stop
$script:docker = $dockerCommand.Source
$script:http = [System.Net.Http.HttpClient]::new()
$script:http.Timeout = [TimeSpan]::FromSeconds(150)
$script:project = "kelimio-import-e2e-$(New-RandomHex 6)"
$project = $script:project
$previousEnvironment = @{}
$configurationValidated = $false
$normalContainersBefore = @()
$normalContainersAfter = @()
$failure = $null
$cleanupFailure = $null
$stage = "runner initialization"

foreach ($name in $environmentNames) {
    $previousEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, "Process")
}

try {
    if ($project -notmatch $projectPattern) { throw "The generated project name is invalid." }
    $normalContainersBefore = @(Invoke-DockerCapture @(
        "compose", "-f", $composePath, "--profile", "app", "ps", "-aq"
    )).Split("`n") | Where-Object { $_ }

    $reserved = [System.Collections.Generic.HashSet[int]]::new()
    $ports = @{
        Postgres = Get-AvailableLoopbackPort $reserved
        Redis = Get-AvailableLoopbackPort $reserved
        LocalStack = Get-AvailableLoopbackPort $reserved
        Keycloak = Get-AvailableLoopbackPort $reserved
        MailpitSmtp = Get-AvailableLoopbackPort $reserved
        MailpitHttp = Get-AvailableLoopbackPort $reserved
        OtelGrpc = Get-AvailableLoopbackPort $reserved
        OtelHttp = Get-AvailableLoopbackPort $reserved
        OtelMetrics = Get-AvailableLoopbackPort $reserved
        Api = Get-AvailableLoopbackPort $reserved
    }
    $databasePassword = "db-$(New-RandomHex 24)"
    $keycloakAdmin = "admin-$(New-RandomHex 6)"
    $keycloakPassword = "Kc!$(New-RandomHex 24)"
    $matchingKey = New-RandomBase64Key
    $cursorKey = New-RandomBase64Key
    $values = @{
        KELIMIO_LOCAL_DB_PASSWORD = $databasePassword
        KELIMIO_LOCAL_KEYCLOAK_ADMIN = $keycloakAdmin
        KELIMIO_LOCAL_KEYCLOAK_PASSWORD = $keycloakPassword
        KELIMIO_LOCAL_POSTGRES_HOST_PORT = "$($ports.Postgres)"
        KELIMIO_LOCAL_REDIS_HOST_PORT = "$($ports.Redis)"
        KELIMIO_LOCAL_LOCALSTACK_HOST_PORT = "$($ports.LocalStack)"
        KELIMIO_LOCALSTACK_IMAGE = "$project-localstack:4.4.0"
        KELIMIO_LOCAL_KEYCLOAK_HOST_PORT = "$($ports.Keycloak)"
        KELIMIO_LOCAL_MAILPIT_SMTP_HOST_PORT = "$($ports.MailpitSmtp)"
        KELIMIO_LOCAL_MAILPIT_HTTP_HOST_PORT = "$($ports.MailpitHttp)"
        KELIMIO_LOCAL_OTEL_GRPC_HOST_PORT = "$($ports.OtelGrpc)"
        KELIMIO_LOCAL_OTEL_HTTP_HOST_PORT = "$($ports.OtelHttp)"
        KELIMIO_LOCAL_OTEL_METRICS_HOST_PORT = "$($ports.OtelMetrics)"
        KELIMIO_LOCAL_API_HOST_PORT = "$($ports.Api)"
        KELIMIO_LOCAL_KEYCLOAK_BASE_URL = "http://localhost:$($ports.Keycloak)"
        KELIMIO_LOCAL_OIDC_ISSUER = "http://localhost:$($ports.Keycloak)/realms/kelimio"
        KELIMIO_MATCHING_REPLAY_ACTIVE_KEY_VERSION = "import-e2e-v1"
        KELIMIO_MATCHING_REPLAY_KEYS = "import-e2e-v1=$matchingKey"
        KELIMIO_LOCAL_IMPORT_CURSOR_HMAC_KEY = $cursorKey
        KELIMIO_BUILD_REVISION = "local-import-e2e"
        KELIMIO_LOCAL_RESTART_POLICY = "no"
    }
    foreach ($entry in $values.GetEnumerator()) {
        [Environment]::SetEnvironmentVariable($entry.Key, $entry.Value, "Process")
    }
    $script:apiBase = "http://localhost:$($ports.Api)"
    $script:keycloakBase = "http://localhost:$($ports.Keycloak)"

    $stage = "isolated configuration validation"
    $configuration = Get-ComposeConfiguration
    Assert-IsolatedComposeConfiguration $configuration
    $configurationValidated = $true

    $stage = "isolated stack startup"
    Write-Host "Building and starting the isolated real-service import stack..."
    Invoke-DockerQuiet (Get-ComposeArguments @("up", "-d", "--build"))
    Wait-IsolatedStack
    Assert-LocalInfrastructure

    $stage = "isolated identity administrator authentication"
    Invoke-DockerQuiet (Get-ComposeArguments @(
        "exec", "-T", "keycloak", "/opt/keycloak/bin/kcadm.sh", "config", "credentials",
        "--config", "/tmp/kelimio-import-e2e.config", "--server", "http://keycloak:8080",
        "--realm", "master", "--user", $keycloakAdmin, "--password", $keycloakPassword
    ))
    $stage = "isolated mobile identity client lookup"
    $mobileClients = Invoke-DockerCapture (Get-ComposeArguments @(
        "exec", "-T", "keycloak", "/opt/keycloak/bin/kcadm.sh", "get", "clients",
        "--config", "/tmp/kelimio-import-e2e.config", "-r", "kelimio", "-q", "clientId=kelimio-mobile"
    )) | ConvertFrom-Json
    $mobileClient = @($mobileClients)
    if ($mobileClient.Count -ne 1) { throw "The isolated mobile OIDC client lookup was ambiguous." }
    $stage = "isolated mobile identity client update"
    Invoke-DockerQuiet (Get-ComposeArguments @(
        "exec", "-T", "keycloak", "/opt/keycloak/bin/kcadm.sh", "update",
        "clients/$($mobileClient[0].id)", "--config", "/tmp/kelimio-import-e2e.config",
        "-r", "kelimio", "-s", "directAccessGrantsEnabled=true"
    ))
    $stage = "isolated access token lifespan update"
    Invoke-DockerQuiet (Get-ComposeArguments @(
        "exec", "-T", "keycloak", "/opt/keycloak/bin/kcadm.sh", "update", "realms/kelimio",
        "--config", "/tmp/kelimio-import-e2e.config", "-s", "accessTokenLifespan=1200"
    ))
    $stage = "isolated owner identity creation"
    $ownerToken = New-CompletedUser "owner"
    $stage = "isolated non-owner identity creation"
    $otherToken = New-CompletedUser "other"

    $stage = "valid workbook import approval and draft commit"
    Write-Host "Testing valid reviewed workbook upload, scan, preview, ownership, approval, and draft commit..."
    $baselineCourseCount = [int] (Invoke-DatabaseScalar "select count(*) from course")
    $workbookBytes = [System.IO.File]::ReadAllBytes($WorkbookPath)
    $validImportId = Start-Import $ownerToken "reviewed-course.xlsx" $workbookBytes
    $validStatus = Wait-ImportStatus $ownerToken $validImportId "PREVIEW_READY"
    if ($validStatus.preview.isValid -ne $true -or
        $validStatus.rulesVersion -ne "xlsx-v2" -or
        $validStatus.preview.rowCount -ne 23 -or
        $validStatus.preview.questionCount -ne 14 -or
        $validStatus.preview.matchingQuestionCount -ne 3 -or
        @($validStatus.preview.requiredClientCapabilities).Count -ne 1 -or
        $validStatus.preview.requiredClientCapabilities[0] -ne "question.matching.v1" -or
        [string]::IsNullOrWhiteSpace($validStatus.approvalBindingSha256)) {
        throw "The reviewed workbook did not produce an approvable preview."
    }
    [void] (Send-Json "GET" "$($script:apiBase)/v1/courses/imports/$validImportId" $otherToken $null "" @(404))
    $preview = Send-Json "GET" "$($script:apiBase)/v1/courses/imports/$validImportId/preview?limit=1" `
        $ownerToken $null "" @(200)
    if (@($preview.Body.items).Count -ne 1 -or
        [string]::IsNullOrWhiteSpace($preview.Body.nextCursor) -or
        $null -eq $preview.Body.items[0].questionOrdinal -or
        [string]::IsNullOrWhiteSpace($preview.Body.items[0].projectedQuestionType) -or
        [string]::IsNullOrWhiteSpace($preview.Body.items[0].compositionKind)) {
        throw "The reviewed workbook preview did not expose bounded cursor pagination."
    }
    [void] (Send-Json "GET" "$($script:apiBase)/v1/courses/imports/$validImportId/preview?limit=1" `
        $otherToken $null "" @(404))
    [void] (Send-Json "GET" "$($script:apiBase)/v1/courses/imports/$validImportId/issues?limit=1" `
        $otherToken $null "" @(404))
    [void] (Send-Json "POST" "$($script:apiBase)/v1/courses/imports/$validImportId/approve" $otherToken @{
        approvalBindingSha256 = $validStatus.approvalBindingSha256
    } ([guid]::NewGuid().ToString()) @(404))
    $cursor = $preview.Body.nextCursor
    $tampered = $cursor.Substring(0, $cursor.Length - 1) + $(if ($cursor.EndsWith("A")) { "B" } else { "A" })
    [void] (Send-Json "GET" `
        "$($script:apiBase)/v1/courses/imports/$validImportId/preview?limit=1&cursor=$([Uri]::EscapeDataString($tampered))" `
        $ownerToken $null "" @(404))
    $approval = Send-Json "POST" "$($script:apiBase)/v1/courses/imports/$validImportId/approve" $ownerToken @{
        approvalBindingSha256 = $validStatus.approvalBindingSha256
    } ([guid]::NewGuid().ToString()) @(201)
    if ($approval.Body.status -ne "APPROVED") { throw "The reviewed preview was not approved." }
    [void] (Wait-ImportStatus $ownerToken $validImportId "APPROVED")
    [void] (Send-Json "POST" "$($script:apiBase)/v1/courses/imports/$validImportId/commit" $otherToken @{
        approvalBindingSha256 = $validStatus.approvalBindingSha256
    } ([guid]::NewGuid().ToString()) @(404))
    [void] (Send-Json "POST" "$($script:apiBase)/v1/courses/imports/$validImportId/commit" $ownerToken @{
        approvalBindingSha256 = (("b" * 64) -join "")
    } ([guid]::NewGuid().ToString()) @(409))
    $commitIdempotencyKey = [guid]::NewGuid().ToString()
    $commit = Send-Json "POST" "$($script:apiBase)/v1/courses/imports/$validImportId/commit" $ownerToken @{
        approvalBindingSha256 = $validStatus.approvalBindingSha256
    } $commitIdempotencyKey @(201)
    if ($commit.Body.status -ne "COMMITTED" -or $commit.Body.created -ne $true -or
        [string]::IsNullOrWhiteSpace($commit.Body.courseId) -or
        [string]::IsNullOrWhiteSpace($commit.Body.contentChangeSetId) -or
        [string]::IsNullOrWhiteSpace($commit.Body.draftReleaseId) -or
        $commit.Body.sourceRowCount -ne 23 -or $commit.Body.questionCount -ne 14 -or
        $commit.Body.matchingQuestionCount -ne 3 -or
        @($commit.Body.requiredClientCapabilities).Count -ne 1 -or
        $commit.Body.requiredClientCapabilities[0] -ne "question.matching.v1") {
        throw "The approved preview did not create one identified draft graph."
    }
    $commitReplay = Send-Json "POST" "$($script:apiBase)/v1/courses/imports/$validImportId/commit" $ownerToken @{
        approvalBindingSha256 = $validStatus.approvalBindingSha256
    } $commitIdempotencyKey @(200)
    if ($commitReplay.Body.created -ne $false -or
        $commitReplay.Body.courseId -ne $commit.Body.courseId -or
        $commitReplay.Body.contentChangeSetId -ne $commit.Body.contentChangeSetId -or
        $commitReplay.Body.draftReleaseId -ne $commit.Body.draftReleaseId -or
        $commitReplay.Body.questionCount -ne $commit.Body.questionCount) {
        throw "The draft commit idempotency replay changed the committed result."
    }
    $committedStatus = Wait-ImportStatus $ownerToken $validImportId "COMMITTED"
    if ($committedStatus.commit.courseId -ne $commit.Body.courseId -or
        $committedStatus.commit.contentChangeSetId -ne $commit.Body.contentChangeSetId -or
        $committedStatus.commit.draftReleaseId -ne $commit.Body.draftReleaseId -or
        $committedStatus.commit.questionCount -ne $commit.Body.questionCount -or
        $committedStatus.commit.matchingQuestionCount -ne $commit.Body.matchingQuestionCount) {
        throw "The committed import status does not reconcile to the immutable draft result."
    }
    $committedPreview = Send-Json "GET" "$($script:apiBase)/v1/courses/imports/$validImportId/preview?limit=1" `
        $ownerToken $null "" @(200)
    if (@($committedPreview.Body.items).Count -ne 1) {
        throw "The immutable preview became unavailable after draft commit."
    }

    $stage = "clean invalid workbook rejection"
    Write-Host "Testing clean invalid bytes through scanner and fail-closed parser validation..."
    $invalidBytes = [System.Text.Encoding]::UTF8.GetBytes("not-an-xlsx-package")
    $invalidImportId = Start-Import $ownerToken "invalid.xlsx" $invalidBytes
    $invalidStatus = Wait-ImportStatus $ownerToken $invalidImportId "VALIDATION_FAILED"
    if ($invalidStatus.preview.isValid -ne $false -or $invalidStatus.preview.errorCount -lt 1) {
        throw "The invalid workbook did not retain a bounded validation report."
    }
    $issues = Send-Json "GET" "$($script:apiBase)/v1/courses/imports/$invalidImportId/issues?limit=100" `
        $ownerToken $null "" @(200)
    if (@($issues.Body.items).Count -lt 1) { throw "The invalid workbook exposed no validation issue." }

    $stage = "malware rejection"
    Write-Host "Testing fail-closed EICAR malware rejection before parser or archive..."
    $eicarCodes = @(88,53,79,33,80,37,64,65,80,91,52,92,80,90,88,53,52,40,80,94,41,55,67,67,41,55,125,36,69,73,67,65,82,45,83,84,65,78,68,65,82,68,45,65,78,84,73,86,73,82,85,83,45,84,69,83,84,45,70,73,76,69,33,36,72,43,72,42)
    $eicarBytes = [byte[]] $eicarCodes
    $malwareImportId = Start-Import $ownerToken "malware.xlsx" $eicarBytes
    $malwareStatus = Wait-ImportStatus $ownerToken $malwareImportId "MALWARE_REJECTED"
    if ($null -ne $malwareStatus.preview -or $null -ne $malwareStatus.approvalBindingSha256 -or
        (Invoke-DatabaseScalar "select count(*) from course_import_preview where import_id = '$malwareImportId'") -ne "0" -or
        (Invoke-DatabaseScalar "select count(*) from course_import_artifact where import_id = '$malwareImportId' and artifact_kind in ('ARCHIVE_SOURCE', 'VALIDATION_REPORT')") -ne "0") {
        throw "A malware-rejected import exposed or persisted preview/archive output."
    }

    $stage = "durable evidence checks"
    if ([int] (Invoke-DatabaseScalar "select count(*) from course") -ne ($baselineCourseCount + 1)) {
        throw "The draft commit did not create exactly one course."
    }
    if ((Invoke-DatabaseScalar "select count(*) from course_import_approval") -ne "1" -or
        (Invoke-DatabaseScalar "select count(*) from course_import_commit") -ne "1" -or
        (Invoke-DatabaseScalar "select count(*) from course_import where status = 'COMMITTED'") -ne "1" -or
        (Invoke-DatabaseScalar "select count(*) from course_import where status = 'VALIDATION_FAILED'") -ne "1" -or
        (Invoke-DatabaseScalar "select count(*) from course_import where status = 'MALWARE_REJECTED'") -ne "1" -or
        (Invoke-DatabaseScalar "select count(*) from course_import_scan where verdict = 'CLEAN'") -ne "2" -or
        (Invoke-DatabaseScalar "select count(*) from course_import_scan where verdict = 'MALWARE'") -ne "1" -or
        (Invoke-DatabaseScalar "select count(*) from course_import_dead_letter") -ne "0") {
        throw "The isolated durable import evidence is inconsistent."
    }
    $courseId = $commit.Body.courseId
    $changeSetId = $commit.Body.contentChangeSetId
    $draftReleaseId = $commit.Body.draftReleaseId
    if ((Invoke-DatabaseScalar "select count(*) from course where id = '$courseId' and publication_status = 'DRAFT' and active_release_id is null") -ne "1" -or
        (Invoke-DatabaseScalar "select count(*) from course_release where id = '$draftReleaseId' and course_id = '$courseId' and status = 'DRAFT'") -ne "1" -or
        (Invoke-DatabaseScalar "select count(*) from content_change_set where id = '$changeSetId' and course_id = '$courseId' and status = 'COMMITTED' and source_reference_id = '$validImportId'") -ne "1" -or
        (Invoke-DatabaseScalar "select count(*) from content_change_set_event where content_change_set_id = '$changeSetId'") -ne "2" -or
        (Invoke-DatabaseScalar "select count(*) from course_origin where course_id = '$courseId' and origin_type = 'EXCEL_IMPORT' and origin_key = '$validImportId'") -ne "1" -or
        (Invoke-DatabaseScalar "select count(*) from enrollment where course_id = '$courseId'") -ne "0") {
        throw "The committed course crossed a draft, origin, history, or enrollment boundary."
    }
    if ((Invoke-DatabaseScalar "select count(*) from content_level where course_id = '$courseId'") -ne "$($validStatus.preview.levelCount)" -or
        (Invoke-DatabaseScalar "select count(*) from content_unit where course_id = '$courseId'") -ne "$($validStatus.preview.unitCount)" -or
        (Invoke-DatabaseScalar "select count(*) from content_topic where course_id = '$courseId'") -ne "$($validStatus.preview.topicCount)" -or
        (Invoke-DatabaseScalar "select count(*) from test_revision where course_id = '$courseId'") -ne "$($validStatus.preview.testCount)" -or
        (Invoke-DatabaseScalar "select count(*) from question_revision where course_id = '$courseId'") -ne "$($validStatus.preview.questionCount)" -or
        (Invoke-DatabaseScalar "select count(*) from question_revision_option o join question_revision q on q.id = o.question_revision_id where q.course_id = '$courseId'") -ne
            (Invoke-DatabaseScalar "select count(*) * 4 from question_revision where course_id = '$courseId' and question_type in ('A','B')") -or
        (Invoke-DatabaseScalar "select count(*) from question_revision q where q.course_id = '$courseId' and q.question_type in ('A','B') and (select count(*) from question_revision_option o where o.question_revision_id = q.id) = 4 and (select count(*) from question_revision_option o where o.question_revision_id = q.id and o.is_correct) = 1") -ne
            (Invoke-DatabaseScalar "select count(*) from question_revision where course_id = '$courseId' and question_type in ('A','B')") -or
        (Invoke-DatabaseScalar "select count(*) from question_revision_option_translation t join question_revision q on q.id = t.question_revision_id where q.course_id = '$courseId'") -ne
            (Invoke-DatabaseScalar "select count(*) * 4 * (select count(*) from course_support_language where course_id = '$courseId') from question_revision where course_id = '$courseId' and question_type = 'A'")) {
        throw "The draft hierarchy counts do not match the exact approved preview."
    }
    if ((Invoke-DatabaseScalar "select count(*) from question_revision_import_composition where import_id = '$validImportId'") -ne "$($validStatus.preview.questionCount)" -or
        (Invoke-DatabaseScalar "select count(*) from question_revision_import_source where import_id = '$validImportId'") -ne "$($validStatus.preview.rowCount)" -or
        (Invoke-DatabaseScalar "select count(*) from question_revision_import_composition where import_id = '$validImportId' and composition_kind = 'MATCHING_GROUP'") -ne "$($validStatus.preview.matchingQuestionCount)" -or
        (Invoke-DatabaseScalar "select count(*) from question_revision_import_source s join question_revision_import_composition c on c.question_revision_id = s.question_revision_id where s.import_id = '$validImportId' and c.composition_kind = 'MATCHING_GROUP'") -ne "12" -or
        (Invoke-DatabaseScalar "select count(*) from question_revision_matching_pair p join question_revision q on q.id = p.question_revision_id where q.course_id = '$courseId'") -ne "12" -or
        (Invoke-DatabaseScalar "select count(*) from question_revision_matching_translation t join question_revision q on q.id = t.question_revision_id where q.course_id = '$courseId'") -ne "36" -or
        (Invoke-DatabaseScalar "select count(*) from course_release_required_capability where course_release_id = '$draftReleaseId' and capability = 'question.matching.v1'") -ne "1") {
        throw "The committed draft lost source lineage, matching composition, or its release capability."
    }
    if ((Invoke-DatabaseScalar "select count(*) from course_release_level_revision where course_release_id = '$draftReleaseId'") -ne "$($validStatus.preview.levelCount)" -or
        (Invoke-DatabaseScalar "select count(*) from course_release_unit_revision where course_release_id = '$draftReleaseId'") -ne "$($validStatus.preview.unitCount)" -or
        (Invoke-DatabaseScalar "select count(*) from course_release_topic_revision where course_release_id = '$draftReleaseId'") -ne "$($validStatus.preview.topicCount)" -or
        (Invoke-DatabaseScalar "select count(*) from course_release_test_hierarchy where course_release_id = '$draftReleaseId'") -ne "$($validStatus.preview.testCount)" -or
        (Invoke-DatabaseScalar "select count(*) from course_release where course_id = '$courseId' and status = 'ACTIVE'") -ne "0" -or
        (Invoke-DatabaseScalar "select count(*) from test_revision where course_id = '$courseId' and status = 'ACTIVE'") -ne "0" -or
        (Invoke-DatabaseScalar "select count(*) from question_revision where course_id = '$courseId' and status = 'ACTIVE'") -ne "0") {
        throw "The immutable draft manifest is incomplete or unexpectedly active."
    }
    if ((Invoke-DatabaseScalar "select count(*) from outbox_event e join outbox_delivery d on d.event_id = e.id where e.event_type = 'course.draft-created-from-import.v2' and e.schema_version = 2 and e.aggregate_id = '$courseId' and e.payload ?& array['eventId','importId','courseId','contentChangeSetId','draftReleaseId','sourceRowCount','questionCount','matchingQuestionCount','testCount','requiredClientCapabilities'] and not (e.payload ?| array['originalFileName','sourceSha256','previewSha256','text','prompt','answer']) and (select count(*) from jsonb_object_keys(e.payload)) = 10 and d.published_at is null") -ne "1") {
        throw "The draft-created outbox fact is missing, delivered, or contains sensitive authoring data."
    }
    if ((Invoke-DatabaseScalar `
        "select count(*) from outbox_event where event_type = 'import.processing-requested.v1' and payload::text ilike '%.xlsx%'") -ne "0") {
        throw "An import filename leaked into the transactional outbox."
    }

    $stage = "reviewed initial release publication"
    Write-Host "Reviewing and activating the exact committed release..."
    [void] (Send-Json "GET" "$($script:apiBase)/v1/courses/$courseId/releases/$draftReleaseId/impact" `
        $otherToken $null "" @(404))
    $impact = Send-Json "GET" "$($script:apiBase)/v1/courses/$courseId/releases/$draftReleaseId/impact" `
        $ownerToken $null "" @(200)
    if ($impact.Body.operation -ne "INITIAL_PUBLICATION" -or
        $null -ne $impact.Body.expectedActiveReleaseId -or
        $impact.Body.sourceChangeSetId -ne $changeSetId -or
        $impact.Body.releaseRevision -ne 1 -or
        $impact.Body.targetQuestionCount -ne 14 -or
        $impact.Body.addedQuestionCount -ne 14 -or
        $impact.Body.affectedEnrollmentCount -ne 0 -or
        @($impact.Body.requiredClientCapabilities).Count -ne 1 -or
        $impact.Body.requiredClientCapabilities[0] -ne "question.matching.v1" -or
        $impact.Body.impactBindingSha256 -notmatch '^[0-9a-f]{64}$') {
        throw "The initial release impact was incomplete or non-deterministic."
    }
    [void] (Send-Json "POST" "$($script:apiBase)/v1/courses/$courseId/releases/$draftReleaseId/activate" `
        $ownerToken @{
            expectedActiveReleaseId = $null
            impactBindingSha256 = (("b" * 64) -join "")
        } ([guid]::NewGuid().ToString()) @(409))
    $activationKey = [guid]::NewGuid().ToString()
    $activation = Send-Json "POST" "$($script:apiBase)/v1/courses/$courseId/releases/$draftReleaseId/activate" `
        $ownerToken @{
            expectedActiveReleaseId = $null
            impactBindingSha256 = $impact.Body.impactBindingSha256
        } $activationKey @(201)
    if ($activation.Body.created -ne $true -or
        $activation.Body.operation -ne "INITIAL_PUBLICATION" -or
        $activation.Body.courseId -ne $courseId -or
        $activation.Body.releaseId -ne $draftReleaseId -or
        $activation.Body.coursePublicationStatus -ne "PUBLISHED" -or
        $activation.Body.reprojectionStatus -ne "PENDING") {
        throw "The reviewed initial release was not activated exactly once."
    }
    $activationReplay = Send-Json "POST" "$($script:apiBase)/v1/courses/$courseId/releases/$draftReleaseId/activate" `
        $ownerToken @{
            expectedActiveReleaseId = $null
            impactBindingSha256 = $impact.Body.impactBindingSha256
        } $activationKey @(200)
    if ($activationReplay.Body.created -ne $false -or
        $activationReplay.Body.activationId -ne $activation.Body.activationId) {
        throw "The release activation idempotency replay changed the durable result."
    }
    [void] (Send-Json "GET" "$($script:apiBase)/v1/courses/$courseId" $ownerToken $null "" @(409))
    $publishedCourse = Send-Json "GET" "$($script:apiBase)/v1/courses/$courseId" `
        $ownerToken $null "" @(200) "question.matching.v1"
    if ($publishedCourse.Body.releaseId -ne $draftReleaseId) {
        throw "The compatible catalog did not expose the activated immutable release."
    }
    $reprojectionDeadline = (Get-Date).AddSeconds(30)
    do {
        $reprojectionStatus = Invoke-DatabaseScalar `
            "select status from course_release_reprojection_job where activation_id = '$($activation.Body.activationId)'"
        if ($reprojectionStatus -eq "COMPLETED") { break }
        Start-Sleep -Milliseconds 250
    } while ((Get-Date) -lt $reprojectionDeadline)
    if ($reprojectionStatus -ne "COMPLETED" -or
        (Invoke-DatabaseScalar "select count(*) from course where id = '$courseId' and publication_status = 'PUBLISHED' and active_release_id = '$draftReleaseId'") -ne "1" -or
        (Invoke-DatabaseScalar "select count(*) from course_release where id = '$draftReleaseId' and status = 'ACTIVE'") -ne "1" -or
        (Invoke-DatabaseScalar "select count(*) from test_revision where course_id = '$courseId' and status = 'ACTIVE'") -ne "$($validStatus.preview.testCount)" -or
        (Invoke-DatabaseScalar "select count(*) from question_revision where course_id = '$courseId' and status = 'ACTIVE'") -ne "$($validStatus.preview.questionCount)" -or
        (Invoke-DatabaseScalar "select count(*) from course_release_activation where id = '$($activation.Body.activationId)' and operation_kind = 'INITIAL_PUBLICATION' and impact_binding_sha256 = '$($impact.Body.impactBindingSha256)'") -ne "1" -or
        (Invoke-DatabaseScalar "select count(*) from outbox_event where event_type = 'content.release-published.v1' and aggregate_id = '$courseId' and not (payload ?| array['text','prompt','answer'])") -ne "1") {
        throw "The release activation, outbox fact, or reprojection completion is inconsistent."
    }
    Wait-QueueDrained "kelimio-import"
    Wait-QueueDrained "kelimio-import-dlq"
    Write-Host "Local import E2E passed: Type-D composition, exact draft boundary, reviewed publication, source lineage, capability gate, idempotency, invalid validation, malware rejection, ownership, reprojection, and queues."
} catch {
    $failure = $_
    try {
        $importState = Invoke-DatabaseScalar @"
select coalesce(string_agg(status || ':' || processing_attempts::text || ':' ||
       coalesce(failure_code, 'none'), ',' order by created_at), 'none') from course_import
"@
        $outboxState = Invoke-DatabaseScalar @"
select count(*)::text || ':' ||
       count(*) filter (where d.published_at is not null)::text || ':' ||
       coalesce(max(d.attempt_count), 0)::text || ':' ||
       coalesce(string_agg(distinct d.last_error, ','), 'none')
  from outbox_event e join outbox_delivery d on d.event_id = e.id
 where e.event_type = 'import.processing-requested.v1'
"@
        $attemptState = Invoke-DatabaseScalar @"
select coalesce(string_agg(attempt_number::text || ':' || outcome || ':' ||
       coalesce(stable_code, 'none'), ',' order by attempt_number), 'none')
  from course_import_processing_attempt
"@
        $queueUrl = Invoke-DockerCapture (Get-ComposeArguments @(
            "exec", "-T", "localstack", "awslocal", "sqs", "get-queue-url",
            "--queue-name", "kelimio-import", "--query", "QueueUrl", "--output", "text"
        ))
        $queueState = Invoke-DockerCapture (Get-ComposeArguments @(
            "exec", "-T", "localstack", "awslocal", "sqs", "get-queue-attributes",
            "--queue-url", $queueUrl, "--attribute-names", "ApproximateNumberOfMessages",
            "ApproximateNumberOfMessagesNotVisible", "--query", "Attributes", "--output", "json"
        ))
        Write-Host "Safe isolated state diagnostics: imports=$importState outbox=$outboxState attempts=$attemptState queue=$queueState"

        $diagnostic = Invoke-DockerCapture (Get-ComposeArguments @(
            "logs", "--no-color", "--tail", "240", "api", "import-worker", "postgres"
        ))
        $safeDiagnostic = @($diagnostic.Split("`n") | Where-Object {
            $_ -match '(?i)\b(error|warn|exception|failure|failed)\b'
        } | ForEach-Object {
            $_ -replace '(?i)(bearer\s+)[^\s]+', '$1[redacted]' `
                -replace '(?i)(X-Amz-(?:Signature|Credential)=)[^&\s]+', '$1[redacted]' `
                -replace '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+', '[redacted-email]'
        })
        if ($safeDiagnostic.Count -gt 0) {
            Write-Host "Safe isolated API/worker error diagnostics:"
            $safeDiagnostic | Select-Object -Last 80 | ForEach-Object { Write-Host $_ }
        }
    } catch {
        Write-Host "Safe isolated API/worker diagnostics were unavailable."
    }
} finally {
    $ownerToken = $null
    $otherToken = $null
    $databasePassword = $null
    $keycloakPassword = $null
    $matchingKey = $null
    $cursorKey = $null
    if ($configurationValidated) {
        try {
            Write-Host "Removing the isolated import test containers and volumes..."
            Invoke-DockerQuiet (Get-ComposeArguments @("down", "--volumes", "--remove-orphans", "--rmi", "local"))
            $localstackImage = "$project-localstack:4.4.0"
            $localstackImageId = Invoke-DockerCapture @(
                "image", "ls", "-q", "--filter", "reference=$localstackImage"
            )
            if (-not [string]::IsNullOrWhiteSpace($localstackImageId)) {
                Invoke-DockerQuiet @("image", "rm", $localstackImage)
            }
            foreach ($kind in @("container", "volume", "network")) {
                $inspectionArguments = if ($kind -eq "container") {
                    @("ps", "-aq", "--filter", "label=com.docker.compose.project=$project")
                } else {
                    @($kind, "ls", "--filter", "label=com.docker.compose.project=$project", "-q")
                }
                $remaining = Invoke-DockerCapture $inspectionArguments
                if (-not [string]::IsNullOrWhiteSpace(($remaining -replace "`0", ""))) {
                    throw "An isolated Docker resource remained after guarded cleanup."
                }
            }
        } catch {
            $cleanupFailure = $_
        }
    }
    foreach ($name in $environmentNames) {
        [Environment]::SetEnvironmentVariable($name, $previousEnvironment[$name], "Process")
    }
    $script:http.Dispose()
    try {
        $normalContainersAfter = @(Invoke-DockerCapture @(
            "compose", "-f", $composePath, "--profile", "app", "ps", "-aq"
        )).Split("`n") | Where-Object { $_ }
        if (@(Compare-Object ($normalContainersBefore | Sort-Object) ($normalContainersAfter | Sort-Object)).Count -ne 0) {
            throw "The normal Compose stack changed during the isolated import test."
        }
    } catch {
        if ($null -eq $cleanupFailure) { $cleanupFailure = $_ }
    }
}

if ($null -ne $failure -and $null -ne $cleanupFailure) {
    $primaryMessage = if ([string]::IsNullOrWhiteSpace($failure.Exception.Message)) {
        "A PowerShell operation failed without a safe diagnostic."
    } else { $failure.Exception.Message }
    $cleanupMessage = if ([string]::IsNullOrWhiteSpace($cleanupFailure.Exception.Message)) {
        "Cleanup failed without a safe diagnostic."
    } else { $cleanupFailure.Exception.Message }
    throw "Local import E2E failed during $stage. $primaryMessage Cleanup also failed. $cleanupMessage"
}
if ($null -ne $failure) {
    $primaryMessage = if ([string]::IsNullOrWhiteSpace($failure.Exception.Message)) {
        "A PowerShell operation failed without a safe diagnostic."
    } else { $failure.Exception.Message }
    throw "Local import E2E failed during $stage. $primaryMessage"
}
if ($null -ne $cleanupFailure) {
    $cleanupMessage = if ([string]::IsNullOrWhiteSpace($cleanupFailure.Exception.Message)) {
        "Cleanup failed without a safe diagnostic."
    } else { $cleanupFailure.Exception.Message }
    throw "Local import E2E cleanup failed. $cleanupMessage"
}
