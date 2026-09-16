param(
    [string]$OutputPath = "..\..\packages\plugged-dream-ptbr-1.0.0.kllang"
)

$ErrorActionPreference = "Stop"
$sourceRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$resolvedOutput = [IO.Path]::GetFullPath((Join-Path $sourceRoot $OutputPath))
$outputDirectory = Split-Path -Parent $resolvedOutput

New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
if (Test-Path -LiteralPath $resolvedOutput) {
    Remove-Item -LiteralPath $resolvedOutput -Force
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::Open($resolvedOutput, [IO.Compression.ZipArchiveMode]::Create)
try {
    $manifest = Join-Path $sourceRoot "translation.json"
    [IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
        $archive,
        $manifest,
        "translation.json",
        [IO.Compression.CompressionLevel]::Optimal
    ) | Out-Null

    $payloadRoot = Join-Path $sourceRoot "payload"
    Get-ChildItem -LiteralPath $payloadRoot -Recurse -File | ForEach-Object {
        $relative = $_.FullName.Substring($sourceRoot.Length + 1).Replace("\", "/")
        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $archive,
            $_.FullName,
            $relative,
            [IO.Compression.CompressionLevel]::Optimal
        ) | Out-Null
    }
} finally {
    $archive.Dispose()
}

Write-Host "Created $resolvedOutput"
Write-Host "SHA-256: $((Get-FileHash -Algorithm SHA256 -LiteralPath $resolvedOutput).Hash.ToLowerInvariant())"
