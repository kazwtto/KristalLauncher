[CmdletBinding()]
param(
    [ValidateSet("Debug", "Release", "All")]
    [string]$Variant = "All"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$artifactsRoot = Join-Path $repositoryRoot "artifacts"
$outputDirectory = Join-Path $artifactsRoot "apk"
$workRoot = Join-Path $artifactsRoot ".work"
$runtimeDex = Join-Path $repositoryRoot "runtime\love2d\classes.dex"
$gradleWrapper = Join-Path $repositoryRoot "gradlew.bat"
$signingPropertiesPath = Join-Path $repositoryRoot ".signing\keystore.properties"
$buildToolsVersion = "34.0.0"

function Invoke-Checked([string]$filePath, [string[]]$arguments) {
    & $filePath @arguments | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) {
        throw "$([System.IO.Path]::GetFileName($filePath)) failed with exit code $LASTEXITCODE."
    }
}

function Get-FileSha256([string]$path) {
    $stream = [System.IO.File]::OpenRead($path)
    $algorithm = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = $algorithm.ComputeHash($stream)
        return -join ($bytes | ForEach-Object { $_.ToString("x2") })
    } finally {
        $algorithm.Dispose()
        $stream.Dispose()
    }
}

function Resolve-Java {
    $candidates = [System.Collections.Generic.List[string]]::new()
    if ($env:JAVA_HOME) {
        $candidates.Add((Join-Path $env:JAVA_HOME "bin\java.exe"))
    }
    $candidates.Add((Join-Path $repositoryRoot ".jdk17\jdk\bin\java.exe"))
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    $command = Get-Command java.exe -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }
    throw "Java was not found. Configure JAVA_HOME or install the local .jdk17 toolchain."
}

function Resolve-AndroidSdk {
    $candidates = [System.Collections.Generic.List[string]]::new()
    if ($env:ANDROID_HOME) {
        $candidates.Add($env:ANDROID_HOME)
    }
    $candidates.Add((Join-Path $repositoryRoot ".android-sdk"))
    foreach ($candidate in $candidates) {
        $buildTools = Join-Path $candidate "build-tools\$buildToolsVersion"
        if (Test-Path -LiteralPath $buildTools) {
            return [System.IO.Path]::GetFullPath($candidate)
        }
    }
    throw "Android SDK Build Tools $buildToolsVersion were not found."
}

function Read-SigningProperties {
    if (-not (Test-Path -LiteralPath $signingPropertiesPath)) {
        throw "Project signing credentials are missing. Run create_keystore.bat first."
    }

    $values = @{}
    foreach ($line in Get-Content -LiteralPath $signingPropertiesPath) {
        $trimmed = $line.Trim()
        if (-not $trimmed -or $trimmed.StartsWith("#")) { continue }
        $separator = $trimmed.IndexOf('=')
        if ($separator -gt 0) {
            $key = $trimmed.Substring(0, $separator).Trim()
            $value = $trimmed.Substring($separator + 1)
            $values[$key] = $value
        }
    }

    foreach ($required in @("storeFile", "storePassword", "keyAlias", "keyPassword")) {
        if (-not $values.ContainsKey($required) -or [string]::IsNullOrWhiteSpace($values[$required])) {
            throw "Signing property '$required' is missing."
        }
    }

    $signingRoot = [System.IO.Path]::GetFullPath((Join-Path $repositoryRoot ".signing"))
    $keystorePath = [System.IO.Path]::GetFullPath((Join-Path $repositoryRoot $values.storeFile))
    if (-not $keystorePath.StartsWith($signingRoot + [System.IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "The project keystore must stay under .signing/."
    }
    if (-not (Test-Path -LiteralPath $keystorePath)) {
        throw "Project keystore not found: $keystorePath"
    }

    return [pscustomobject]@{
        KeystorePath = $keystorePath
        StorePassword = $values.storePassword
        KeyAlias = $values.keyAlias
        KeyPassword = $values.keyPassword
    }
}

function Remove-SafeWorkDirectory([string]$path) {
    $fullPath = [System.IO.Path]::GetFullPath($path)
    $fullWorkRoot = [System.IO.Path]::GetFullPath($workRoot)
    if (-not $fullPath.StartsWith($fullWorkRoot + [System.IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove unexpected build path: $fullPath"
    }
    if (Test-Path -LiteralPath $fullPath) {
        Remove-Item -LiteralPath $fullPath -Recurse -Force
    }
}

function Merge-RuntimeDex([string]$inputApk, [string]$workDirectory, [string]$java, [string]$d8Jar) {
    $mergedArchive = Join-Path $workDirectory "merged-classes.zip"
    $mergedDirectory = Join-Path $workDirectory "merged-classes"
    $workingApk = Join-Path $workDirectory "runtime-merged-unaligned.apk"

    Invoke-Checked $java @(
        "-cp", $d8Jar,
        "com.android.tools.r8.D8",
        "--release",
        "--min-api", "24",
        "--output", $mergedArchive,
        $inputApk,
        $runtimeDex
    )

    New-Item -ItemType Directory -Path $mergedDirectory -Force | Out-Null
    [System.IO.Compression.ZipFile]::ExtractToDirectory($mergedArchive, $mergedDirectory)
    $dexFiles = @(Get-ChildItem -LiteralPath $mergedDirectory -File | Where-Object {
        $_.Name -match '^classes(\d+)?\.dex$'
    } | Sort-Object Name)
    if ($dexFiles.Count -eq 0) {
        throw "D8 did not produce a classes.dex file."
    }

    Copy-Item -LiteralPath $inputApk -Destination $workingApk -Force
    $archive = [System.IO.Compression.ZipFile]::Open(
        $workingApk,
        [System.IO.Compression.ZipArchiveMode]::Update
    )
    try {
        $obsoleteEntries = @($archive.Entries | Where-Object {
            $_.FullName -match '^classes(\d+)?\.dex$' -or
            $_.FullName -match '^(?i:META-INF/(?:MANIFEST\.MF|.*\.(?:SF|RSA|DSA|EC)))$'
        })
        foreach ($entry in $obsoleteEntries) {
            $entry.Delete()
        }
        foreach ($dexFile in $dexFiles) {
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $archive,
                $dexFile.FullName,
                $dexFile.Name,
                [System.IO.Compression.CompressionLevel]::Optimal
            ) | Out-Null
        }
    } finally {
        $archive.Dispose()
    }
    return $workingApk
}

function Build-Variant(
    [string]$variantName,
    [string]$versionName,
    [string]$java,
    [string]$d8Jar,
    [string]$zipalign,
    [string]$apksigner,
    [object]$signing
) {
    $variantLower = $variantName.ToLowerInvariant()
    $workDirectory = Join-Path $workRoot $variantLower
    Remove-SafeWorkDirectory $workDirectory
    New-Item -ItemType Directory -Path $workDirectory -Force | Out-Null

    try {
        Write-Host "Building $variantLower APK..."
        Invoke-Checked $gradleWrapper @("assemble$variantName")

        $inputApk = if ($variantName -eq "Debug") {
            Join-Path $repositoryRoot "app\build\outputs\apk\debug\app-debug.apk"
        } else {
            Join-Path $repositoryRoot "app\build\outputs\apk\release\app-release-unsigned.apk"
        }
        if (-not (Test-Path -LiteralPath $inputApk)) {
            throw "Gradle output was not found: $inputApk"
        }

        Write-Host "Merging the embedded LOVE2D runtime..."
        $mergedApk = Merge-RuntimeDex $inputApk $workDirectory $java $d8Jar
        $alignedApk = Join-Path $workDirectory "runtime-merged-aligned.apk"
        Invoke-Checked $zipalign @("-f", "-p", "4", $mergedApk, $alignedApk)

        $signedApk = Join-Path $workDirectory "signed.apk"
        Write-Host "Signing with the Kristal Launcher project keystore..."
        $previousStorePassword = [Environment]::GetEnvironmentVariable(
            "KRISTAL_LAUNCHER_STORE_PASSWORD",
            "Process"
        )
        $previousKeyPassword = [Environment]::GetEnvironmentVariable(
            "KRISTAL_LAUNCHER_KEY_PASSWORD",
            "Process"
        )
        $env:KRISTAL_LAUNCHER_STORE_PASSWORD = $signing.StorePassword
        $env:KRISTAL_LAUNCHER_KEY_PASSWORD = $signing.KeyPassword
        try {
            Invoke-Checked $apksigner @(
                "sign",
                "--ks", $signing.KeystorePath,
                "--ks-key-alias", $signing.KeyAlias,
                "--ks-pass", "env:KRISTAL_LAUNCHER_STORE_PASSWORD",
                "--key-pass", "env:KRISTAL_LAUNCHER_KEY_PASSWORD",
                "--v4-signing-enabled", "false",
                "--out", $signedApk,
                $alignedApk
            )
        } finally {
            if ($null -eq $previousStorePassword) {
                Remove-Item Env:\KRISTAL_LAUNCHER_STORE_PASSWORD -ErrorAction SilentlyContinue
            } else {
                $env:KRISTAL_LAUNCHER_STORE_PASSWORD = $previousStorePassword
            }
            if ($null -eq $previousKeyPassword) {
                Remove-Item Env:\KRISTAL_LAUNCHER_KEY_PASSWORD -ErrorAction SilentlyContinue
            } else {
                $env:KRISTAL_LAUNCHER_KEY_PASSWORD = $previousKeyPassword
            }
        }
        Invoke-Checked $apksigner @("verify", "--verbose", "--print-certs", $signedApk)

        $safeVersion = $versionName -replace '[^0-9A-Za-z._-]', '-'
        $artifactName = "KristalLauncher-v$safeVersion-$variantLower.apk"
        $artifactPath = Join-Path $outputDirectory $artifactName
        if (Test-Path -LiteralPath $artifactPath) {
            Remove-Item -LiteralPath $artifactPath -Force
        }
        Move-Item -LiteralPath $signedApk -Destination $artifactPath

        $hash = Get-FileSha256 $artifactPath
        Write-Host "Created: $artifactPath"
        Write-Host "SHA-256: $hash"
        return $artifactPath
    } finally {
        Remove-SafeWorkDirectory $workDirectory
    }
}

if (-not (Test-Path -LiteralPath $runtimeDex)) {
    throw "Embedded runtime DEX not found: $runtimeDex"
}
if (-not (Test-Path -LiteralPath $gradleWrapper)) {
    throw "Gradle wrapper not found: $gradleWrapper"
}

$versionMatch = [regex]::Match(
    [System.IO.File]::ReadAllText((Join-Path $repositoryRoot "app\build.gradle.kts")),
    'versionName\s*=\s*"([^"]+)"'
)
if (-not $versionMatch.Success) {
    throw "Could not read versionName from app/build.gradle.kts."
}
$versionName = $versionMatch.Groups[1].Value

$java = Resolve-Java
$androidSdk = Resolve-AndroidSdk
$buildTools = Join-Path $androidSdk "build-tools\$buildToolsVersion"
$d8Jar = Join-Path $buildTools "lib\d8.jar"
$zipalign = Join-Path $buildTools "zipalign.exe"
$apksigner = Join-Path $buildTools "apksigner.bat"
foreach ($requiredTool in @($d8Jar, $zipalign, $apksigner)) {
    if (-not (Test-Path -LiteralPath $requiredTool)) {
        throw "Required Android build tool not found: $requiredTool"
    }
}

$signing = Read-SigningProperties
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
New-Item -ItemType Directory -Path $workRoot -Force | Out-Null

$previousJavaHome = [Environment]::GetEnvironmentVariable("JAVA_HOME", "Process")
$env:JAVA_HOME = Split-Path (Split-Path $java -Parent) -Parent
$artifacts = [System.Collections.Generic.List[string]]::new()
Push-Location $repositoryRoot
try {
    if ($Variant -in @("Debug", "All")) {
        $artifacts.Add((Build-Variant "Debug" $versionName $java $d8Jar $zipalign $apksigner $signing))
    }
    if ($Variant -in @("Release", "All")) {
        $artifacts.Add((Build-Variant "Release" $versionName $java $d8Jar $zipalign $apksigner $signing))
    }
} finally {
    Pop-Location
    if ($null -eq $previousJavaHome) {
        Remove-Item Env:\JAVA_HOME -ErrorAction SilentlyContinue
    } else {
        $env:JAVA_HOME = $previousJavaHome
    }
    if ((Test-Path -LiteralPath $workRoot) -and -not (Get-ChildItem -LiteralPath $workRoot -Force)) {
        Remove-Item -LiteralPath $workRoot -Force
    }
}

Write-Output ""
Write-Output "Build completed. Artifacts:"
$artifacts | ForEach-Object { Write-Output "- $_" }
