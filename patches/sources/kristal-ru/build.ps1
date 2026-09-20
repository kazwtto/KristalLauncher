param()

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$sourceRoot = $PSScriptRoot
$payloadRoot = Join-Path $sourceRoot "payload"
$overlayRoot = Join-Path $payloadRoot "overlay"
$manifestPath = Join-Path $sourceRoot "patch.json"
$version = "1.0.0"
$packagePath = Join-Path (Split-Path (Split-Path $sourceRoot -Parent) -Parent) "packages\kristal-ru-$version.klpatch"

$operations = [System.Collections.Generic.List[object]]::new()
$operations.Add([ordered]@{
    type = "inject"
    source = "payload/kristal_ru/runtime.lua"
    target = "kristal_ru/runtime.lua"
})
$operations.Add([ordered]@{
    type = "append_text"
    source = "payload/bootstrap.lua"
    target = "main.lua"
})

Get-ChildItem -LiteralPath $overlayRoot -Recurse -File | Sort-Object FullName | ForEach-Object {
    $source = $_.FullName.Substring($sourceRoot.Length + 1).Replace('\', '/')
    $target = $_.FullName.Substring($overlayRoot.Length + 1).Replace('\', '/')
    $operations.Add([ordered]@{
        type = "inject"
        source = $source
        target = $target
        replaceExisting = $true
    })
}

$manifest = [ordered]@{
    schemaVersion = 1
    id = "kristal.ru"
    version = $version
    name = [ordered]@{
        "pt-BR" = "Kristal Engine em Russo"
        en = "Kristal Engine in Russian"
        es = "Kristal Engine en Ruso"
    }
    description = [ordered]@{
        "pt-BR" = "Adapta a tradução comunitária kristal_rus, incluindo textos, fontes e elementos gráficos russos. A cobertura original ainda é parcial."
        en = "Adapts the kristal_rus community translation, including Russian text, fonts, and interface graphics. Upstream coverage is still partial."
        es = "Adapta la traducción comunitaria kristal_rus, incluidos textos, fuentes y gráficos de interfaz en ruso. La cobertura original aún es parcial."
    }
    useCases = @(
        [ordered]@{
            "pt-BR" = "Você quer usar menus, personagens, magias e gráficos russos fornecidos pelo projeto kristal_rus."
            en = "You want the Russian menus, characters, spells, and graphics supplied by kristal_rus."
            es = "Quieres usar los menús, personajes, hechizos y gráficos rusos proporcionados por kristal_rus."
        }
    )
    author = "neofarsh; sprites and textures by LazyDesman"
    category = "localization"
    minimumLauncherVersion = "0.17.48"
    priority = 200
    capabilities = @("staged_package", "inject_files", "edit_lua", "runtime_hook")
    dependencies = @()
    conflicts = @("kristal.ptbr", "kristal.es")
    operations = $operations
}

$json = $manifest | ConvertTo-Json -Depth 12
[System.IO.File]::WriteAllText($manifestPath, $json + "`n", [System.Text.UTF8Encoding]::new($false))

$temporary = "$packagePath.tmp"
if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force }
$archive = [System.IO.Compression.ZipFile]::Open($temporary, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    $files = @(
        Get-Item -LiteralPath $manifestPath
        Get-Item -LiteralPath (Join-Path $sourceRoot "README.md")
        Get-Item -LiteralPath (Join-Path $sourceRoot "UPSTREAM_README.md")
        Get-ChildItem -LiteralPath $payloadRoot -Recurse -File | Sort-Object FullName
    )
    foreach ($file in $files) {
        $entry = $file.FullName.Substring($sourceRoot.Length + 1).Replace('\', '/')
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $archive,
            $file.FullName,
            $entry,
            [System.IO.Compression.CompressionLevel]::Optimal
        ) | Out-Null
    }
} finally {
    $archive.Dispose()
}
Move-Item -LiteralPath $temporary -Destination $packagePath -Force
Write-Output "Operations: $($operations.Count)"
Write-Output "Package: $packagePath"
Write-Output "SHA-256: $((Get-FileHash -LiteralPath $packagePath -Algorithm SHA256).Hash.ToLowerInvariant())"
