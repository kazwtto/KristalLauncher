@echo off
setlocal

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\build-apks.ps1" -Variant All
exit /b %errorlevel%
