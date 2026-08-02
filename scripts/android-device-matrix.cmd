@echo off
setlocal
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%~dp0android-device-matrix.ps1" %*
exit /b %ERRORLEVEL%
