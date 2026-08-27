@echo off
setlocal EnableExtensions DisableDelayedExpansion

rem Repository cleanup is intentionally allowlisted. Keep required toolchains,
rem Gradle caches, signing tools, local.properties, source files, and final APKs.
set "CLEANUP_TARGETS=.love_dex;.love_only;.love_only_extracted;tools;scripts patches;icon;frostveil.love;Godhome.love;Sprite-0002.ase;test.lua;test_ast.lua;change_version.bat;notesmd.md;PORT_ANDROID_GUIA.md;Relatorio_e_Guia_de_Correcao.md;RELATORIO_ERRO_SHADER.md;RELATORIO_TEXTO_ANDROID.md;RELATORIO_SHADERS_ANDROID.md;RELATORIO_PORT_ANDROID.md;RELATORIO_PATCH_TELA_CHEIA.md;RELATORIO_PATCH_BORDAS.md;relatorio_integracao_gamepad.md;app\src\main\assets\gamepad_patch;patches\packages\kristal-ptbr-2.3.1.klpatch;cmdline-tools.zip;jdk17.zip;assets.7z;frostveil_patched.love;love_built.apk;love_only.apk;love-android.apk;combined_dex.zip;merged_app.zip;merged_classes.zip;.merged_dex_tmp;love_decoded;frost_test;godhome_test;test_patch;gamepad_dev;syntax_check.lua;AGENTS.md;skills;.agents;.agent;.codex;.claude;.cursor;.continue;.openai;.windsurf;CLAUDE.md;GEMINI.md"

echo Kristal Launcher repository cleanup
echo Repository: %~dp0
echo.

rem Preview the exact existing targets and their current sizes without changing anything.
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference = 'Stop'; $root = [IO.Path]::GetFullPath('%~dp0').TrimEnd([IO.Path]::DirectorySeparatorChar); $targets = $env:CLEANUP_TARGETS -split ';'; $totalFiles = 0L; $totalBytes = 0L; foreach ($relative in $targets) { $full = [IO.Path]::GetFullPath((Join-Path $root $relative)); if ($full -eq $root -or -not $full.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe cleanup target: ' + $relative }; if (Test-Path -LiteralPath $full) { $item = Get-Item -LiteralPath $full -Force; $files = if ($item.PSIsContainer) { @(Get-ChildItem -LiteralPath $full -Recurse -File -Force -ErrorAction SilentlyContinue) } else { @($item) }; $bytes = [long](($files | Measure-Object -Property Length -Sum).Sum); $totalFiles += $files.Count; $totalBytes += $bytes; [PSCustomObject]@{ Target = $relative; Files = $files.Count; MiB = [math]::Round($bytes / 1MB, 2) } } }; Write-Host ''; Write-Host ('Total: {0:N0} files, {1:N2} MiB' -f $totalFiles, ($totalBytes / 1MB))"
if errorlevel 1 (
    echo.
    echo Preview failed. Nothing was deleted.
    exit /b 1
)

if /I not "%~1"=="--execute" (
    echo.
    echo Preview mode only. Nothing was deleted.
    echo To execute later, run: cleanup_repository.bat --execute
    exit /b 0
)

echo.
echo WARNING: Untracked files cannot be restored by Git.
echo Required SDK/JDK installations, Gradle caches, signing tools, local.properties,
echo runtime/love2d/classes.dex, artwork/play-store-icon.png, and app/build are preserved.
set /p "CLEANUP_CONFIRM=Type DELETE to remove every existing target listed above: "
if /I not "%CLEANUP_CONFIRM%"=="DELETE" (
    echo Cleanup cancelled. Nothing was deleted.
    exit /b 0
)

rem PowerShell performs validation and deletion end-to-end to avoid cross-shell path handling.
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference = 'Stop'; $root = [IO.Path]::GetFullPath('%~dp0').TrimEnd([IO.Path]::DirectorySeparatorChar); $targets = $env:CLEANUP_TARGETS -split ';'; foreach ($relative in $targets) { $full = [IO.Path]::GetFullPath((Join-Path $root $relative)); if ($full -eq $root -or -not $full.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe cleanup target: ' + $relative }; if (Test-Path -LiteralPath $full) { Write-Host ('Removing ' + $relative); Remove-Item -LiteralPath $full -Recurse -Force } }; Write-Host 'Cleanup completed.'"
if errorlevel 1 (
    echo Cleanup stopped because an error occurred.
    exit /b 1
)

exit /b 0
