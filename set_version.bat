@echo off
setlocal
if "%~1"=="" (
    echo Usage: set_version.bat [versionName] [versionCode]
    echo Example: set_version.bat 0.17.1 18
    exit /b 1
)
if "%~2"=="" (
    echo Usage: set_version.bat [versionName] [versionCode]
    echo Example: set_version.bat 0.17.1 18
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0set_version.ps1" -VersionName "%~1" -VersionCode "%~2"
exit /b %errorlevel%
