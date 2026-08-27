@echo off
setlocal
if "%~1"=="" (
    echo Usage: set_version.bat [versionName] [versionCode]
    echo Example: set_version.bat 0.1.5 5
    exit /b 1
)
if "%~2"=="" (
    echo Usage: set_version.bat [versionName] [versionCode]
    echo Example: set_version.bat 0.1.5 5
    exit /b 1
)

set "NEW_VERSION_NAME=%~1"
set "NEW_VERSION_CODE=%~2"
echo %NEW_VERSION_CODE%| findstr /r /x "[1-9][0-9]*" >nul
if errorlevel 1 (
    echo versionCode must be a positive integer.
    exit /b 1
)

echo Updating to version %NEW_VERSION_NAME% (code %NEW_VERSION_CODE%)...
powershell -NoProfile -Command "$file = '%~dp0app\build.gradle.kts'; $content = [IO.File]::ReadAllText($file); $content = $content -replace 'versionCode = \d+', 'versionCode = %NEW_VERSION_CODE%'; $content = $content -replace 'versionName = \"[^\"]+\"', 'versionName = \"%NEW_VERSION_NAME%\"'; [IO.File]::WriteAllText($file, $content, [Text.UTF8Encoding]::new($false))"
if errorlevel 1 exit /b 1

echo Version updated successfully in app/build.gradle.kts.
