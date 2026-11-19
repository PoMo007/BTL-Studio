@echo off
chcp 65001 >nul
title Lemon Studio - Build from source (slow)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Build-From-Source.ps1" %*
echo.
pause
