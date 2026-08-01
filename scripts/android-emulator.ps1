[CmdletBinding()]
param(
    [ValidateSet("setup", "start", "status", "stop")]
    [string] $Action = "start",
    [string] $AvdName = "kelimio_api36",
    [switch] $Headless,
    [ValidateRange(30, 600)]
    [int] $BootTimeoutSeconds = 180
)

$ErrorActionPreference = "Stop"

$apiLevel = 36
$buildToolsVersion = "36.0.0"
$systemImage = "system-images;android-36;google_apis;x86_64"
$deviceProfile = "pixel_7"
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
        (Join-Path $sdkRoot "platforms\android-$apiLevel\android.jar"),
        (Join-Path $sdkRoot "build-tools\$buildToolsVersion\aapt2.exe"),
        (Join-Path $sdkRoot "system-images\android-$apiLevel\google_apis\x86_64\system.img")
    )
    $missing = @($requiredFiles | Where-Object { -not (Test-Path -LiteralPath $_) })
    if ($missing.Count -eq 0) {
        return
    }

    & $sdkManager --sdk_root="$sdkRoot" `
        "platform-tools" `
        "emulator" `
        "platforms;android-$apiLevel" `
        "build-tools;$buildToolsVersion" `
        $systemImage
    if ($LASTEXITCODE -ne 0) {
        throw "Android SDK package installation failed with exit code $LASTEXITCODE."
    }

    $stillMissing = @($requiredFiles | Where-Object { -not (Test-Path -LiteralPath $_) })
    if ($stillMissing.Count -gt 0) {
        throw "Android SDK installation completed without all required files: $($stillMissing -join ', ')"
    }
}

function Ensure-Avd {
    Assert-AndroidPackages

    $avdList = (& $avdManager list avd 2>&1) -join "`n"
    if ($avdList -notmatch "(?m)^\s*Name:\s+$([Regex]::Escape($AvdName))\s*$") {
        "no" | & $avdManager create avd `
            --name $AvdName `
            --package $systemImage `
            --device $deviceProfile
        if ($LASTEXITCODE -ne 0) {
            throw "AVD creation failed with exit code $LASTEXITCODE."
        }
    }

    $configPath = Join-Path $env:USERPROFILE ".android\avd\$AvdName.avd\config.ini"
    if (-not (Test-Path -LiteralPath $configPath)) {
        throw "AVD configuration was not created at $configPath."
    }

    Set-IniValue -Path $configPath -Key "PlayStore.enabled" -Value "no"
    Set-IniValue -Path $configPath -Key "fastboot.forceColdBoot" -Value "yes"
    Set-IniValue -Path $configPath -Key "fastboot.forceFastBoot" -Value "no"
    Set-IniValue -Path $configPath -Key "firstboot.bootFromDownloadableSnapshot" -Value "no"
    Set-IniValue -Path $configPath -Key "firstboot.bootFromLocalSnapshot" -Value "no"
    Set-IniValue -Path $configPath -Key "firstboot.saveToLocalSnapshot" -Value "no"
    Set-IniValue -Path $configPath -Key "hw.gpu.enabled" -Value "yes"
    Set-IniValue -Path $configPath -Key "hw.gpu.mode" -Value "software"

    Write-Host "Android AVD is ready: $AvdName (API $apiLevel, Google APIs, no Play Store)"
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
        if ($reportedName -eq $AvdName) {
            return $serial
        }
    }
    return $null
}

function Write-EmulatorStatus {
    $serial = Get-KelimioEmulatorSerial
    if (-not $serial) {
        Write-Host "$AvdName is stopped."
        return
    }

    $bootCompleted = ((& $adb -s $serial shell getprop sys.boot_completed 2>$null) | Out-String).Trim()
    $androidVersion = ((& $adb -s $serial shell getprop ro.build.version.release 2>$null) | Out-String).Trim()
    Write-Host "$AvdName is running as $serial; Android $androidVersion; boot_completed=$bootCompleted"
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
            Write-Host "$AvdName is already stopped."
            break
        }
        & $adb -s $serial emu kill | Out-Null
        Write-Host "Stopped $AvdName ($serial)."
    }
    "start" {
        Ensure-Avd
        $serial = Get-KelimioEmulatorSerial
        if (-not $serial) {
            $logRoot = Join-Path $env:LOCALAPPDATA "Kelimio\emulator-logs"
            New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
            $stdout = Join-Path $logRoot "$AvdName.stdout.log"
            $stderr = Join-Path $logRoot "$AvdName.stderr.log"
            $arguments = @(
                "-avd", $AvdName,
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
            $stderr = Join-Path $env:LOCALAPPDATA "Kelimio\emulator-logs\$AvdName.stderr.log"
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
