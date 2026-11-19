@echo off
chcp 65001 >nul
title Lemon Studio - Install / Update
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Lemon-Studio-Setup.ps1" %*
echo.
pause
