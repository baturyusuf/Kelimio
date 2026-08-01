@echo off
setlocal
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%~dp0local-android-e2e.ps1" %*
exit /b %ERRORLEVEL%
