[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ApplicationId,

    [string]$DeviceId
)

. (Join-Path $PSScriptRoot "common.ps1")

Assert-KelimioCommand "adb"

$adbArgs = @()
if (-not [string]::IsNullOrWhiteSpace($DeviceId)) {
    $adbArgs += @("-s", $DeviceId)
}

$packagePath = & adb @adbArgs shell pm path $ApplicationId
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($packagePath)) {
    throw "$ApplicationId is not installed on the selected device."
}

Invoke-KelimioCommand adb @adbArgs shell monkey `
    -p $ApplicationId `
    -c android.intent.category.LAUNCHER `
    1

Start-Sleep -Seconds 5
$pid = (& adb @adbArgs shell pidof $ApplicationId).Trim()
if ([string]::IsNullOrWhiteSpace($pid)) {
    throw "$ApplicationId did not remain running after launch."
}

$log = & adb @adbArgs logcat --pid=$pid -d -t 300
if ($LASTEXITCODE -ne 0) {
    throw "Could not read application logcat."
}
$fatal = $log | Select-String -Pattern "FATAL EXCEPTION|AndroidRuntime.*Process:"
if ($fatal) {
    $fatal | ForEach-Object { Write-Error $_.Line }
    throw "A fatal Android runtime error was detected."
}

Write-Host "Installed-app smoke check passed for $ApplicationId (PID $pid)."
