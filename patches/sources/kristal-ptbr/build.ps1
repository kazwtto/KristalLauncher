param()

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Web.Extensions
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$jsonSerializer = [System.Web.Script.Serialization.JavaScriptSerializer]::new()
$jsonSerializer.MaxJsonLength = [int]::MaxValue
$sourceRoot = $PSScriptRoot
$textRoot = Join-Path $sourceRoot "source-text"
$payloadRoot = Join-Path $sourceRoot "payload"
$translationOutput = Join-Path $payloadRoot "kristal_pt\translations.lua"
$manifestOutput = Join-Path $sourceRoot "patch.json"
$packageOutput = Join-Path (Split-Path (Split-Path $sourceRoot -Parent) -Parent) "packages\kristal-ptbr-2.3.2.klpatch"

$categoryPriority = @(
    "ui", "menus", "config", "battle", "gameover", "shops", "system",
    "characters", "items", "light_items", "key_items", "weapons", "armors",
    "spells", "reactions"
)

function ConvertTo-LuaString([string]$value) {
    $escaped = [System.Text.StringBuilder]::new($value.Length)
    foreach ($character in $value.ToCharArray()) {
        $codePoint = [int]$character
        if ($codePoint -eq 8) {
            [void]$escaped.Append('\b')
        } elseif ($codePoint -eq 9) {
            [void]$escaped.Append('\t')
        } elseif ($codePoint -eq 10) {
            [void]$escaped.Append('\n')
        } elseif ($codePoint -eq 12) {
            [void]$escaped.Append('\f')
        } elseif ($codePoint -eq 13) {
            [void]$escaped.Append('\r')
        } elseif ($codePoint -eq 34) {
            [void]$escaped.Append('\"')
        } elseif ($codePoint -eq 92) {
            [void]$escaped.Append('\\')
        } elseif ($codePoint -lt 32) {
            [void]$escaped.Append("\$($codePoint.ToString('000'))")
        } else {
            [void]$escaped.Append($character)
        }
    }
    return '"' + $escaped.ToString() + '"'
}

$translationsByKey = [System.Collections.Generic.Dictionary[string,System.Collections.Generic.HashSet[string]]]::new(
    [System.StringComparer]::Ordinal
)
foreach ($category in $categoryPriority) {
    $path = Join-Path $textRoot "$category.json"
    if (-not (Test-Path -LiteralPath $path)) { continue }
    $mapping = $jsonSerializer.DeserializeObject((Get-Content -LiteralPath $path -Raw))
    foreach ($key in $mapping.Keys) {
        $translated = [string]$mapping[$key]
        if ([string]::IsNullOrWhiteSpace($translated)) { continue }
        if (-not $translationsByKey.ContainsKey($key)) {
            $translationsByKey[$key] = [System.Collections.Generic.HashSet[string]]::new(
                [System.StringComparer]::Ordinal
            )
        }
        [void]$translationsByKey[$key].Add($translated)
    }
}

$resolvedTranslations = [System.Collections.Generic.Dictionary[string,string]]::new(
    [System.StringComparer]::Ordinal
)
$ambiguousKeys = [System.Collections.Generic.List[string]]::new()
foreach ($key in $translationsByKey.Keys) {
    $values = $translationsByKey[$key]
    if ($values.Count -eq 1) {
        $resolvedTranslations[$key] = @($values)[0]
    } else {
        $ambiguousKeys.Add($key)
    }
}

$translationKeys = [string[]]$resolvedTranslations.Keys
[System.Array]::Sort($translationKeys, [System.StringComparer]::Ordinal)

$exact = [System.Collections.Generic.List[object]]::new()
$dynamic = [System.Collections.Generic.List[object]]::new()
foreach ($key in $translationKeys) {
    $translated = $resolvedTranslations[$key]
    if ($translated -eq $key) { continue }

    $sourcePlaceholders = @([regex]::Matches($key, '\{lua(\d+)\}') | ForEach-Object {
        [int]$_.Groups[1].Value
    })
    $targetPlaceholders = @([regex]::Matches($translated, '\{lua(\d+)\}') | ForEach-Object {
        [int]$_.Groups[1].Value
    })
    $sourceSignature = (($sourcePlaceholders | Sort-Object) -join ',')
    $targetSignature = (($targetPlaceholders | Sort-Object) -join ',')
    if ($sourcePlaceholders.Count -ne $targetPlaceholders.Count -or $sourceSignature -ne $targetSignature) {
        throw "Invalid dynamic placeholders for translation key: $key"
    }

    if ($sourcePlaceholders.Count -gt 0) {
        $dynamic.Add([pscustomobject]@{ source = $key; target = $translated })
    } else {
        $exact.Add([pscustomobject]@{ source = $key; target = $translated })
    }
}

$luaLines = [System.Collections.Generic.List[string]]::new()
$luaLines.Add("-- Generated from KristalPT 2.3.1 categorized JSON maps. Do not edit manually.")
$luaLines.Add("return {")
$luaLines.Add("    exact = {")
foreach ($entry in $exact) {
    $luaLines.Add("        [$(ConvertTo-LuaString $entry.source)] = $(ConvertTo-LuaString $entry.target),")
}
$luaLines.Add("    },")
$luaLines.Add("    dynamic = {")
foreach ($entry in $dynamic) {
    $luaLines.Add("        { source = $(ConvertTo-LuaString $entry.source), target = $(ConvertTo-LuaString $entry.target) },")
}
$luaLines.Add("    },")
$luaLines.Add("}")

$translationDirectory = Split-Path $translationOutput -Parent
New-Item -ItemType Directory -Path $translationDirectory -Force | Out-Null
[System.IO.File]::WriteAllLines($translationOutput, $luaLines, [System.Text.UTF8Encoding]::new($false))

$operations = [System.Collections.Generic.List[object]]::new()
$operations.Add([ordered]@{
    type = "inject"
    source = "payload/kristal_pt/runtime.lua"
    target = "kristal_pt/runtime.lua"
})
$operations.Add([ordered]@{
    type = "inject"
    source = "payload/kristal_pt/translations.lua"
    target = "kristal_pt/translations.lua"
})
$operations.Add([ordered]@{
    type = "append_text"
    source = "payload/bootstrap.lua"
    target = "main.lua"
})

$graphicsRoot = Join-Path $payloadRoot "graphics"
Get-ChildItem -LiteralPath $graphicsRoot -Recurse -File | Sort-Object FullName | ForEach-Object {
    $relative = $_.FullName.Substring($sourceRoot.Length + 1).Replace('\', '/')
    $target = $_.FullName.Substring($graphicsRoot.Length + 1).Replace('\', '/')
    $operations.Add([ordered]@{
        type = "inject"
        source = $relative
        target = $target
        replaceExisting = $true
    })
}

$manifest = [ordered]@{
    schemaVersion = 1
    id = "kristal.ptbr"
    version = "2.3.2"
    name = [ordered]@{
        "pt-BR" = "Kristal Engine em Português (Brasil)"
        en = "Kristal Engine in Brazilian Portuguese"
        es = "Kristal Engine en portugués de Brasil"
    }
    description = [ordered]@{
        "pt-BR" = "Traduz menus, textos integrados e elementos gráficos da Kristal Engine para português do Brasil."
        en = "Translates built-in Kristal Engine menus, text, and interface graphics into Brazilian Portuguese."
        es = "Traduce los menús, textos integrados y gráficos de interfaz de Kristal Engine al portugués de Brasil."
    }
    useCases = @(
        [ordered]@{
            "pt-BR" = "Você quer jogar mods da Kristal com menus e mensagens da engine em português."
            en = "You want Kristal mods to show engine menus and messages in Brazilian Portuguese."
            es = "Quieres que los mods de Kristal muestren menús y mensajes del motor en portugués de Brasil."
        },
        [ordered]@{
            "pt-BR" = "Botões, telas de batalha ou imagens da interface ainda aparecem em inglês."
            en = "Buttons, battle screens, or interface graphics still appear in English."
            es = "Los botones, pantallas de batalla o gráficos de interfaz todavía aparecen en inglés."
        }
    )
    author = "kazwtto"
    category = "localization"
    minimumLauncherVersion = "0.1.0"
    priority = 200
    capabilities = @("staged_package", "inject_files", "edit_lua", "runtime_hook")
    dependencies = @()
    conflicts = @()
    operations = $operations
}

$manifestJson = $manifest | ConvertTo-Json -Depth 12
[System.IO.File]::WriteAllText($manifestOutput, $manifestJson + "`n", [System.Text.UTF8Encoding]::new($false))

$packageDirectory = Split-Path $packageOutput -Parent
New-Item -ItemType Directory -Path $packageDirectory -Force | Out-Null
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
        Get-Item -LiteralPath $manifestOutput
        Get-Item -LiteralPath (Join-Path $sourceRoot "README.md")
        Get-ChildItem -LiteralPath $payloadRoot -Recurse -File | Sort-Object FullName
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

$hash = (Get-FileHash -LiteralPath $packageOutput -Algorithm SHA256).Hash.ToLowerInvariant()
Write-Output "Exact translations: $($exact.Count)"
Write-Output "Dynamic translations: $($dynamic.Count)"
Write-Output "Ambiguous translations skipped: $($ambiguousKeys.Count)"
Write-Output "Operations: $($operations.Count)"
Write-Output "Package: $packageOutput"
Write-Output "SHA-256: $hash"
