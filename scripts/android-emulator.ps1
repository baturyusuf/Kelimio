[CmdletBinding()]
param(
    [ValidateSet("setup", "start", "status", "stop")]
    [string] $Action = "start",
    [ValidateSet("api24-min", "api30-mid", "api36-current")]
    [string] $Profile = "api36-current",
    [switch] $Headless,
    [ValidateRange(30, 600)]
    [int] $BootTimeoutSeconds = 180
)

$ErrorActionPreference = "Stop"

$compileApiLevel = 36
$buildToolsVersion = "36.0.0"
$profiles = @{
    "api24-min" = @{
        AvdName = "kelimio_api24_min"
        ApiLevel = 24
        SystemImage = "system-images;android-24;google_apis;x86_64"
        DeviceProfile = "Nexus 5"
    }
    "api30-mid" = @{
        AvdName = "kelimio_api30_mid"
        ApiLevel = 30
        SystemImage = "system-images;android-30;google_apis;x86_64"
        DeviceProfile = "pixel_3a"
    }
    "api36-current" = @{
        AvdName = "kelimio_api36"
        ApiLevel = 36
        SystemImage = "system-images;android-36;google_apis;x86_64"
        DeviceProfile = "pixel_7"
    }
}
$selectedProfile = $profiles[$Profile]
$avdName = [string] $selectedProfile.AvdName
$apiLevel = [int] $selectedProfile.ApiLevel
$systemImage = [string] $selectedProfile.SystemImage
$deviceProfile = [string] $selectedProfile.DeviceProfile
$reversePorts = @(8080, 8081)

function Resolve-AndroidSdkRoot {
    $candidates = @(
        $env:ANDROID_SDK_ROOT,
        $env:ANDROID_HOME,
        [Environment]::GetEnvironmentVariable("ANDROID_SDK_ROOT", "User"),
        [Environment]::GetEnvironmentVariable("ANDROID_HOME", "User"),
        (Join-Path $env:LOCALAPPDATA "Android\Sdk")
    ) | Where-Object { $_ }

    foreach ($candidate in $candidates) {
        $resolved = [System.IO.Path]::GetFullPath($candidate)
        if (Test-Path -LiteralPath (Join-Path $resolved "cmdline-tools\latest\bin\sdkmanager.bat")) {
            return $resolved
        }
    }

    throw "Android command-line tools are missing. Install the pinned workstation prerequisites before running this script."
}

function Resolve-JavaHome {
    $candidates = @(
        $env:JAVA_HOME,
        [Environment]::GetEnvironmentVariable("JAVA_HOME", "User")
    ) | Where-Object { $_ }

    foreach ($candidate in $candidates) {
        $resolved = [System.IO.Path]::GetFullPath($candidate)
        if (Test-Path -LiteralPath (Join-Path $resolved "bin\java.exe")) {
            return $resolved
        }
    }

    throw "Java 21 is missing or JAVA_HOME is not configured."
}

function Set-IniValue {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path,
        [Parameter(Mandatory = $true)]
        [string] $Key,
        [Parameter(Mandatory = $true)]
        [string] $Value
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.AddRange([string[]](Get-Content -LiteralPath $Path))
    $prefix = "$Key="
    $index = -1
    for ($current = 0; $current -lt $lines.Count; $current++) {
        if ($lines[$current].StartsWith($prefix, [System.StringComparison]::Ordinal)) {
            $index = $current
            break
        }
    }

    if ($index -ge 0) {
        $lines[$index] = "$Key=$Value"
    } else {
        $lines.Add("$Key=$Value")
    }
    [System.IO.File]::WriteAllLines($Path, $lines)
}

$sdkRoot = Resolve-AndroidSdkRoot
$env:ANDROID_HOME = $sdkRoot
$env:ANDROID_SDK_ROOT = $sdkRoot
$env:JAVA_HOME = Resolve-JavaHome

$sdkManager = Join-Path $sdkRoot "cmdline-tools\latest\bin\sdkmanager.bat"
$avdManager = Join-Path $sdkRoot "cmdline-tools\latest\bin\avdmanager.bat"
$emulator = Join-Path $sdkRoot "emulator\emulator.exe"
$adb = Join-Path $sdkRoot "platform-tools\adb.exe"

function Assert-AndroidPackages {
    $requiredFiles = @(
        $adb,
        $emulator,
        (Join-Path $sdkRoot "platforms\android-$compileApiLevel\android.jar"),
        (Join-Path $sdkRoot "build-tools\$buildToolsVersion\aapt2.exe"),
        (Join-Path $sdkRoot "system-images\android-$apiLevel\google_apis\x86_64\system.img")
    )
    $missing = @($requiredFiles | Where-Object { -not (Test-Path -LiteralPath $_) })
    if ($missing.Count -eq 0) {
        return
    }

    # Command-line Tools 22 writes a deprecation notice to stderr even when
    # sdkmanager succeeds. Windows PowerShell 5.1 promotes that line to an
    # error record under Stop, so capture the native exit code explicitly.
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $sdkManagerOutput = @(& $sdkManager --sdk_root="$sdkRoot" `
            "platform-tools" `
            "emulator" `
            "platforms;android-$compileApiLevel" `
            "build-tools;$buildToolsVersion" `
            $systemImage 2>&1)
        $sdkManagerExitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
    }
    if ($sdkManagerExitCode -ne 0) {
        $safeTail = @($sdkManagerOutput | Select-Object -Last 20) -join "`n"
        throw "Android SDK package installation failed with exit code $sdkManagerExitCode.`n$safeTail"
    }

    $stillMissing = @($requiredFiles | Where-Object { -not (Test-Path -LiteralPath $_) })
    if ($stillMissing.Count -gt 0) {
        throw "Android SDK installation completed without all required files: $($stillMissing -join ', ')"
    }
}

function Ensure-Avd {
    Assert-AndroidPackages

    $avdList = (& $avdManager list avd 2>&1) -join "`n"
    if ($avdList -notmatch "(?m)^\s*Name:\s+$([Regex]::Escape($avdName))\s*$") {
        "no" | & $avdManager create avd `
            --name $avdName `
            --package $systemImage `
            --device $deviceProfile
        if ($LASTEXITCODE -ne 0) {
            throw "AVD creation failed with exit code $LASTEXITCODE."
        }
    }

    $configPath = Join-Path $env:USERPROFILE ".android\avd\$avdName.avd\config.ini"
    if (-not (Test-Path -LiteralPath $configPath)) {
        throw "AVD configuration was not created at $configPath."
    }

    $configuration = @{}
    foreach ($line in Get-Content -LiteralPath $configPath) {
        $separator = $line.IndexOf('=')
        if ($separator -gt 0) {
            $configuration[$line.Substring(0, $separator)] = $line.Substring($separator + 1)
        }
    }
    $expectedImageDirectory = "system-images\android-$apiLevel\google_apis\x86_64\"
    if ($configuration["image.sysdir.1"] -ne $expectedImageDirectory -or
        $configuration["hw.device.name"] -ne $deviceProfile) {
        throw "The repository-owned AVD '$avdName' does not match profile '$Profile'; refusing to modify it."
    }

    Set-IniValue -Path $configPath -Key "PlayStore.enabled" -Value "no"
    Set-IniValue -Path $configPath -Key "fastboot.forceColdBoot" -Value "yes"
    Set-IniValue -Path $configPath -Key "fastboot.forceFastBoot" -Value "no"
    Set-IniValue -Path $configPath -Key "firstboot.bootFromDownloadableSnapshot" -Value "no"
    Set-IniValue -Path $configPath -Key "firstboot.bootFromLocalSnapshot" -Value "no"
    Set-IniValue -Path $configPath -Key "firstboot.saveToLocalSnapshot" -Value "no"
    Set-IniValue -Path $configPath -Key "hw.gpu.enabled" -Value "yes"
    Set-IniValue -Path $configPath -Key "hw.gpu.mode" -Value "software"

    Write-Host "Android AVD is ready: $avdName (API $apiLevel, $deviceProfile, Google APIs, no Play Store)"
}

function Get-KelimioEmulatorSerial {
    if (-not (Test-Path -LiteralPath $adb)) {
        return $null
    }

    $serials = @(& $adb devices | ForEach-Object {
        if ($_ -match '^(emulator-\d+)\s+device$') {
            $Matches[1]
        }
    })
    foreach ($serial in $serials) {
        $reportedName = @(& $adb -s $serial emu avd name 2>$null) | Select-Object -First 1
        if ($reportedName -eq $avdName) {
            return $serial
        }
    }
    return $null
}

function Write-EmulatorStatus {
    $serial = Get-KelimioEmulatorSerial
    if (-not $serial) {
        Write-Host "$avdName is stopped."
        return
    }

    $bootCompleted = ((& $adb -s $serial shell getprop sys.boot_completed 2>$null) | Out-String).Trim()
    $androidVersion = ((& $adb -s $serial shell getprop ro.build.version.release 2>$null) | Out-String).Trim()
    $reportedApiLevel = ((& $adb -s $serial shell getprop ro.build.version.sdk 2>$null) | Out-String).Trim()
    if ($reportedApiLevel -ne $apiLevel.ToString()) {
        throw "$avdName reported API $reportedApiLevel instead of expected API $apiLevel."
    }
    Write-Host "$avdName is running as $serial; Android $androidVersion / API $reportedApiLevel; boot_completed=$bootCompleted"
}

switch ($Action) {
    "setup" {
        Ensure-Avd
    }
    "status" {
        Write-EmulatorStatus
    }
    "stop" {
        $serial = Get-KelimioEmulatorSerial
        if (-not $serial) {
            Write-Host "$avdName is already stopped."
            break
        }
        & $adb -s $serial emu kill | Out-Null
        Write-Host "Stopped $avdName ($serial)."
    }
    "start" {
        Ensure-Avd
        $serial = Get-KelimioEmulatorSerial
        if (-not $serial) {
            $logRoot = Join-Path $env:LOCALAPPDATA "Kelimio\emulator-logs"
            New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
            $stdout = Join-Path $logRoot "$avdName.stdout.log"
            $stderr = Join-Path $logRoot "$avdName.stderr.log"
            $arguments = @(
                "-avd", $avdName,
                "-no-snapshot",
                "-no-boot-anim",
                "-gpu", "software",
                "-netdelay", "none",
                "-netspeed", "full"
            )
            if ($Headless) {
                $arguments += "-no-window"
            }
            Start-Process `
                -FilePath $emulator `
                -ArgumentList $arguments `
                -RedirectStandardOutput $stdout `
                -RedirectStandardError $stderr `
                -WindowStyle $(if ($Headless) { "Hidden" } else { "Normal" })
        }

        $deadline = (Get-Date).AddSeconds($BootTimeoutSeconds)
        $bootCompleted = ""
        do {
            $serial = Get-KelimioEmulatorSerial
            if ($serial) {
                $bootCompleted = ((& $adb -s $serial shell getprop sys.boot_completed 2>$null) | Out-String).Trim()
                if ($bootCompleted -eq "1") {
                    break
                }
            }
            Start-Sleep -Seconds 2
        } while ((Get-Date) -lt $deadline)

        if (-not $serial -or $bootCompleted -ne "1") {
            $stderr = Join-Path $env:LOCALAPPDATA "Kelimio\emulator-logs\$avdName.stderr.log"
            $tail = if (Test-Path -LiteralPath $stderr) {
                (Get-Content -LiteralPath $stderr -Tail 80) -join "`n"
            } else {
                "No emulator error log was created."
            }
            throw "Android emulator did not boot within $BootTimeoutSeconds seconds.`n$tail"
        }

        foreach ($port in $reversePorts) {
            & $adb -s $serial reverse "tcp:$port" "tcp:$port" | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "Unable to reverse emulator TCP port $port."
            }
        }
        Write-EmulatorStatus
        Write-Host "Reversed emulator ports: $($reversePorts -join ', ')"
    }
}
