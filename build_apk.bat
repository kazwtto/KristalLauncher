@echo off
setlocal

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\build-apks.ps1" -Variant Debug
exit /b %errorlevel%
