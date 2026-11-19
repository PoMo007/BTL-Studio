@echo off
chcp 65001 >nul
title BTL Sync - Undo last
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Sync.ps1" -Undo
echo.
pause
