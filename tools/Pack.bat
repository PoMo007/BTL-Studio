@echo off
chcp 65001 >nul
title BTL Pack
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Pack.ps1" %*
echo.
pause
