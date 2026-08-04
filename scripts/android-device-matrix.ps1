[CmdletBinding()]
param(
    [switch] $Headless,
    [switch] $IncludeEndpointE2e,
    [ValidateRange(60, 600)]
    [int] $BootTimeoutSeconds = 300
)

$ErrorActionPreference = "Stop"

$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$mobilePath = Join-Path $repositoryRoot "mobile"
$emulatorScript = Join-Path $PSScriptRoot "android-emulator.ps1"
$e2eScript = Join-Path $PSScriptRoot "local-android-e2e.ps1"
$normalPackage = "com.kelimio.app"
$smokePackage = "com.kelimio.app.smoke"
$profiles = @(
    [pscustomobject]@{
        Key = "api24-min"
        AvdName = "kelimio_api24_min"
        ApiLevel = 24
        Device = "Nexus 5"
        RunEndpointE2e = $true
    },
    [pscustomobject]@{
        Key = "api30-mid"
        AvdName = "kelimio_api30_mid"
        ApiLevel = 30
        Device = "Pixel 3a"
        RunEndpointE2e = $false
    },
    [pscustomobject]@{
        Key = "api36-current"
        AvdName = "kelimio_api36"
        ApiLevel = 36
        Device = "Pixel 7"
        RunEndpointE2e = $true
    }
)
$profileByAvdName = @{}
foreach ($profile in $profiles) {
    $profileByAvdName[$profile.AvdName] = $profile
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
    throw "Android platform tools are missing."
}

function Get-RunningEmulators {
    param([string] $Adb)

    $result = [System.Collections.Generic.List[object]]::new()
    foreach ($line in @(& $Adb devices 2>$null)) {
        if ($line -notmatch '^(emulator-\d+)\s+device$') {
            continue
        }
        $serial = $Matches[1]
        $avdName = (@(& $Adb -s $serial emu avd name 2>$null) | Select-Object -First 1).Trim()
        if ([string]::IsNullOrWhiteSpace($avdName)) {
            throw "Unable to identify the running Android emulator $serial."
        }
        $result.Add([pscustomobject]@{ Serial = $serial; AvdName = $avdName })
    }
    return @($result)
}

function Get-EmulatorSerial {
    param([string] $Adb, [string] $AvdName)

    $matches = @(Get-RunningEmulators -Adb $Adb | Where-Object { $_.AvdName -eq $AvdName })
    if ($matches.Count -gt 1) {
        throw "More than one running emulator reports repository AVD '$AvdName'."
    }
    if ($matches.Count -eq 0) {
        return $null
    }
    return $matches[0].Serial
}

function Wait-EmulatorStopped {
    param([string] $Adb, [string] $AvdName)

    $deadline = (Get-Date).AddSeconds(30)
    do {
        if (-not (Get-EmulatorSerial -Adb $Adb -AvdName $AvdName)) {
            return
        }
        Start-Sleep -Milliseconds 500
    } while ((Get-Date) -lt $deadline)
    throw "Repository AVD '$AvdName' did not stop in time."
}

function Test-AndroidPackageInstalled {
    param([string] $Adb, [string] $Serial, [string] $PackageName)

    if ($PackageName -notin @($normalPackage, $smokePackage)) {
        throw "The Android package guard rejected '$PackageName'."
    }
    $packages = @(& $Adb -s $Serial shell pm list packages $PackageName 2>$null)
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to inspect guarded Android package '$PackageName'."
    }
    $matches = @($packages | Where-Object { $_.Trim() -eq "package:$PackageName" })
    if ($matches.Count -gt 1) {
        throw "The guarded Android package lookup was ambiguous."
    }
    return $matches.Count -eq 1
}

function Remove-SmokeApplication {
    param([string] $Adb, [string] $Serial)

    if (-not (Test-AndroidPackageInstalled -Adb $Adb -Serial $Serial -PackageName $smokePackage)) {
        return
    }
    $result = ((& $Adb -s $Serial uninstall $smokePackage 2>$null) -join "").Trim()
    if ($LASTEXITCODE -ne 0 -or $result -ne "Success") {
        throw "Unable to remove the isolated Android smoke package."
    }
}

function Get-ReverseMappings {
    param([string] $Adb, [string] $Serial)

    $result = [System.Collections.Generic.List[object]]::new()
    foreach ($line in @(& $Adb -s $Serial reverse --list 2>$null)) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }
        $parts = @($line.Trim() -split '\s+')
        if ($parts.Count -lt 3 -or
            $parts[$parts.Count - 2] -notmatch '^tcp:\d+$' -or
            $parts[$parts.Count - 1] -notmatch '^tcp:\d+$') {
            throw "An existing Android reverse mapping has an unsupported shape."
        }
        $result.Add([pscustomobject]@{
            Remote = $parts[$parts.Count - 2]
            Local = $parts[$parts.Count - 1]
        })
    }
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to inspect Android reverse-port mappings."
    }
    return @($result)
}

function Restore-ReverseMappings {
    param([string] $Adb, [string] $Serial, [object[]] $Mappings)

    & $Adb -s $Serial reverse --remove-all 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to clear generated Android reverse-port mappings during restoration."
    }
    foreach ($mapping in $Mappings) {
        if ($mapping.Remote -notmatch '^tcp:\d+$' -or $mapping.Local -notmatch '^tcp:\d+$') {
            throw "The Android reverse mapping restore guard rejected a mapping."
        }
        & $Adb -s $Serial reverse $mapping.Remote $mapping.Local 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Unable to restore an Android reverse-port mapping."
        }
    }
}

function Invoke-EmulatorAction {
    param(
        [string] $Action,
        [object] $Profile,
        [switch] $RunHeadless
    )

    if ($RunHeadless -and $Action -eq "start") {
        & $emulatorScript `
            -Action $Action `
            -Profile $Profile.Key `
            -BootTimeoutSeconds $BootTimeoutSeconds `
            -Headless
        return
    }
    & $emulatorScript `
        -Action $Action `
        -Profile $Profile.Key `
        -BootTimeoutSeconds $BootTimeoutSeconds
}

function Start-MatrixEmulator {
    param([string] $Adb, [object] $Profile, [switch] $RunHeadless)

    Invoke-EmulatorAction -Action "start" -Profile $Profile -RunHeadless:$RunHeadless
    $serial = Get-EmulatorSerial -Adb $Adb -AvdName $Profile.AvdName
    if (-not $serial) {
        throw "The matrix could not resolve the serial for '$($Profile.AvdName)'."
    }
    $reportedApi = ((& $Adb -s $serial shell getprop ro.build.version.sdk 2>$null) | Out-String).Trim()
    $reportedAbi = ((& $Adb -s $serial shell getprop ro.product.cpu.abi 2>$null) | Out-String).Trim()
    if ($reportedApi -ne $Profile.ApiLevel.ToString() -or $reportedAbi -ne "x86_64") {
        throw "The matrix runtime identity check failed for '$($Profile.AvdName)'."
    }
    return $serial
}

function Stop-MatrixEmulator {
    param([string] $Adb, [object] $Profile)

    Invoke-EmulatorAction -Action "stop" -Profile $Profile
    Wait-EmulatorStopped -Adb $Adb -AvdName $Profile.AvdName
}

function Invoke-SmokeTests {
    param([string] $Flutter, [string] $Serial)

    $testFiles = @(
        "integration_test/startup_smoke_test.dart",
        "integration_test/secure_storage_smoke_test.dart",
        "integration_test/auth_restore_smoke_test.dart"
    )
    $arguments = @("test") + $testFiles + @(
        "-d", $Serial,
        "--flavor", "smoke",
        "--dart-define=KELIMIO_API_BASE_URL=http://localhost:8080",
        "--dart-define=KELIMIO_OIDC_ISSUER=http://localhost:8081/realms/kelimio",
        "--dart-define=KELIMIO_OIDC_CLIENT_ID=kelimio-mobile",
        "--dart-define=KELIMIO_OIDC_REDIRECT_URI=com.kelimio.app.smoke:/oauthredirect",
        "--dart-define=KELIMIO_OIDC_POST_LOGOUT_REDIRECT_URI=com.kelimio.app.smoke:/logout",
        "--dart-define=KELIMIO_ISOLATED_DEVICE_TEST_STORAGE=true",
        "--dart-define=KELIMIO_LOCAL_DEVELOPMENT_TOOLS=true"
    )

    Push-Location $mobilePath
    try {
        & $Flutter @arguments
        if ($LASTEXITCODE -ne 0) {
            throw "The isolated Android device smoke suite failed with exit code $LASTEXITCODE."
        }
    } finally {
        Pop-Location
    }
}

$adb = Resolve-Adb
$flutter = (Get-Command flutter -ErrorAction Stop).Source
$mutex = [System.Threading.Mutex]::new($false, "Local\KelimioAndroidDeviceMatrix")
$mutexHeld = $false
$originalState = [System.Collections.Generic.List[object]]::new()
$activeProfile = $null
$activeSerial = $null
$failure = $null
$cleanupFailure = $null
$stage = "matrix initialization"

try {
    try {
        $mutexHeld = $mutex.WaitOne(0)
    } catch [System.Threading.AbandonedMutexException] {
        $mutexHeld = $true
    }
    if (-not $mutexHeld) {
        throw "Another Kelimio Android device-matrix run is already active."
    }

    $stage = "existing emulator snapshot"
    $runningEmulators = @(Get-RunningEmulators -Adb $adb)
    $unexpected = @($runningEmulators | Where-Object { -not $profileByAvdName.ContainsKey($_.AvdName) })
    if ($unexpected.Count -gt 0) {
        throw "A non-Kelimio Android emulator is running; the matrix refused to alter emulator state."
    }
    foreach ($running in $runningEmulators) {
        $profile = $profileByAvdName[$running.AvdName]
        $originalState.Add([pscustomobject]@{
            Profile = $profile
            ReverseMappings = @(Get-ReverseMappings -Adb $adb -Serial $running.Serial)
            NormalPackageInstalled = Test-AndroidPackageInstalled `
                -Adb $adb `
                -Serial $running.Serial `
                -PackageName $normalPackage
        })
    }

    $stage = "matrix AVD setup"
    foreach ($profile in $profiles) {
        Invoke-EmulatorAction -Action "setup" -Profile $profile
    }

    $stage = "temporary stop of repository emulators"
    foreach ($state in $originalState) {
        Stop-MatrixEmulator -Adb $adb -Profile $state.Profile
    }

    foreach ($profile in $profiles) {
        $stage = "$($profile.Key) startup"
        $activeProfile = $profile
        $activeSerial = Start-MatrixEmulator -Adb $adb -Profile $profile -RunHeadless:$Headless
        $normalPackageBefore = Test-AndroidPackageInstalled `
            -Adb $adb `
            -Serial $activeSerial `
            -PackageName $normalPackage

        $stage = "$($profile.Key) isolated smoke preflight"
        Remove-SmokeApplication -Adb $adb -Serial $activeSerial

        $stage = "$($profile.Key) five-check Android smoke suite"
        Write-Host "Running 5 isolated Android checks on $($profile.AvdName) (API $($profile.ApiLevel), $($profile.Device))..."
        Invoke-SmokeTests -Flutter $flutter -Serial $activeSerial

        $stage = "$($profile.Key) isolated smoke cleanup"
        Remove-SmokeApplication -Adb $adb -Serial $activeSerial
        $normalPackageAfter = Test-AndroidPackageInstalled `
            -Adb $adb `
            -Serial $activeSerial `
            -PackageName $normalPackage
        if ($normalPackageAfter -ne $normalPackageBefore) {
            throw "The normal Android application installation changed during '$($profile.Key)'."
        }

        if ($IncludeEndpointE2e -and $profile.RunEndpointE2e) {
            $stage = "$($profile.Key) real local endpoint E2E"
            & $e2eScript -DeviceId $activeSerial
        }

        $stage = "$($profile.Key) stop"
        Stop-MatrixEmulator -Adb $adb -Profile $profile
        $activeProfile = $null
        $activeSerial = $null
        Write-Host "Passed $($profile.Key): 5/5 isolated Android checks."
    }
} catch {
    $failure = [System.Exception]::new("Android device matrix failed during $stage. $($_.Exception.Message)")
} finally {
    if ($activeProfile) {
        try {
            if ($activeSerial) {
                Remove-SmokeApplication -Adb $adb -Serial $activeSerial
            }
            Stop-MatrixEmulator -Adb $adb -Profile $activeProfile
        } catch {
            $cleanupFailure = [System.Exception]::new(
                "The active repository AVD could not be cleaned up safely. $($_.Exception.Message)"
            )
        }
    }

    foreach ($state in $originalState) {
        try {
            $serial = Start-MatrixEmulator -Adb $adb -Profile $state.Profile
            Restore-ReverseMappings -Adb $adb -Serial $serial -Mappings $state.ReverseMappings
            $normalPackageRestored = Test-AndroidPackageInstalled `
                -Adb $adb `
                -Serial $serial `
                -PackageName $normalPackage
            if ($normalPackageRestored -ne $state.NormalPackageInstalled) {
                throw "The normal Android application installation was not preserved."
            }
        } catch {
            $cleanupFailure = [System.Exception]::new(
                "The original repository emulator state could not be restored. $($_.Exception.Message)"
            )
        }
    }

    if ($mutexHeld) {
        $mutex.ReleaseMutex()
    }
    $mutex.Dispose()
}

if ($cleanupFailure) {
    if ($failure) {
        throw [System.Exception]::new("$($failure.Message) Cleanup also failed: $($cleanupFailure.Message)")
    }
    throw $cleanupFailure
}
if ($failure) {
    throw $failure
}

Write-Host "Android device matrix passed: 3 profiles and 15/15 isolated checks."
if ($IncludeEndpointE2e) {
    Write-Host "Endpoint real-service E2E also passed on API 24 and API 36."
}
