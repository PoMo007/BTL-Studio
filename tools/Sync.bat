@echo off
chcp 65001 >nul
title BTL Sync
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Sync.ps1" %*
echo.
pause
