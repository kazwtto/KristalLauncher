[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$repository = Split-Path $PSScriptRoot -Parent
$catalog = Get-Content (Join-Path $PSScriptRoot 'catalog.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$results = @()

foreach ($item in $catalog.translations) {
    if ($item.targetLanguage -notin @('pt-BR', 'es')) { continue }
    $sources = @(Get-ChildItem (Join-Path $PSScriptRoot 'sources') -Filter translation.json -Recurse |
        Where-Object { (Get-Content $_.FullName -Raw -Encoding UTF8 | ConvertFrom-Json).id -eq $item.id })
    if ($sources.Count -ne 1) { throw "Expected one source for $($item.id)" }
    $manifestFile = $sources[0]
    $manifest = Get-Content $manifestFile.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
    $root = $manifestFile.Directory.FullName
    $files = @('translation.json')
    if ($manifest.textsFile) {
        $texts = Join-Path $root $manifest.textsFile
        if ((Get-FileHash $texts -Algorithm SHA256).Hash.ToLowerInvariant() -ne $manifest.textsSha256) {
            throw "Text checksum mismatch: $($manifest.id)"
        }
        $files += $manifest.textsFile
    }
    foreach ($file in $manifest.files) {
        if ((Get-FileHash (Join-Path $root $file.source) -Algorithm SHA256).Hash.ToLowerInvariant() -ne $file.translatedSha256) {
            throw "File checksum mismatch: $($manifest.id)"
        }
        $files += $file.source
    }
    if ($manifest.fonts.Count -ne 2) { throw "Expected bitmap font pair: $($manifest.id)" }
    foreach ($font in $manifest.fonts) {
        if ($font.source -notin @('fonts/plain.png', 'fonts/plain.json')) { throw 'Invalid font path' }
        if ((Get-FileHash (Join-Path $root $font.source) -Algorithm SHA256).Hash.ToLowerInvariant() -ne $font.sha256) {
            throw "Font checksum mismatch: $($manifest.id)"
        }
        $files += $font.source
    }
    $name = "$($manifestFile.Directory.Name)-$($manifest.version).kllang"
    $destination = Join-Path $PSScriptRoot "packages/$name"
    if (Test-Path -LiteralPath $destination) { throw "Refusing to overwrite existing package: $destination" }
    $archive = [System.IO.Compression.ZipFile]::Open($destination, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($relative in $files) {
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $archive, (Join-Path $root $relative), $relative,
                [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
        }
    } finally { $archive.Dispose() }
    $results += [pscustomobject]@{
        id = $manifest.id
        version = $manifest.version
        package = "packages/$name"
        sha256 = (Get-FileHash $destination -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    Write-Output "$($manifest.id) $($manifest.version): packaged with verified font pair"
}

$reportDirectory = Join-Path $repository 'artifacts/font-update'
New-Item -ItemType Directory -Path $reportDirectory -Force | Out-Null
$report = $results | ConvertTo-Json -Depth 8
[System.IO.File]::WriteAllText((Join-Path $reportDirectory 'rebuilt.json'), $report, [System.Text.UTF8Encoding]::new($false))
