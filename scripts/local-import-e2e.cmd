@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0local-import-e2e.ps1" %*
exit /b %errorlevel%
