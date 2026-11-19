@echo off
chcp 65001 >nul
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Lemon-Studio-Setup.ps1" -CheckOnly
echo.
pause
