@echo off
setlocal
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%~dp0android-emulator.ps1" %*
exit /b %ERRORLEVEL%
