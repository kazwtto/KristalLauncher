@echo off
setlocal

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\create-project-keystore.ps1"
exit /b %errorlevel%
