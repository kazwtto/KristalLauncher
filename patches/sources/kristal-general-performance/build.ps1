param()

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$sourceRoot = $PSScriptRoot
$patchesRoot = Split-Path (Split-Path $sourceRoot -Parent) -Parent
$packageOutput = Join-Path $patchesRoot "packages\kristal-general-performance-0.0.2.klpatch"
$temporaryArchive = "$packageOutput.tmp.zip"

if (Test-Path -LiteralPath $temporaryArchive) {
    Remove-Item -LiteralPath $temporaryArchive -Force
}

$archive = [System.IO.Compression.ZipFile]::Open(
    $temporaryArchive,
    [System.IO.Compression.ZipArchiveMode]::Create
)
try {
    $packageFiles = @(
        Get-Item -LiteralPath (Join-Path $sourceRoot "patch.json")
        Get-Item -LiteralPath (Join-Path $sourceRoot "README.md")
        Get-ChildItem -LiteralPath (Join-Path $sourceRoot "payload") -Recurse -File | Sort-Object FullName
    )
    foreach ($file in $packageFiles) {
        $entryName = $file.FullName.Substring($sourceRoot.Length + 1).Replace('\', '/')
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $archive,
            $file.FullName,
            $entryName,
            [System.IO.Compression.CompressionLevel]::Optimal
        ) | Out-Null
    }
} finally {
    $archive.Dispose()
}

Move-Item -LiteralPath $temporaryArchive -Destination $packageOutput -Force
Get-FileHash -LiteralPath $packageOutput -Algorithm SHA256
