# Creating patches

Kristal Launcher patches are ZIP archives with the `.klpatch` extension. They describe deterministic changes applied only to the private staged copy of a game. The original `.love`, `.zip`, or `.exe` selected by the user is never modified.

Use a patch for compatibility fixes, optional runtime hooks, localization files, or other changes that can be expressed as file injection and exact UTF-8 text edits.

## Package structure

`patch.json` must be at the archive root. Files referenced by operations belong under `payload/`.

```text
example-patch/
├── patch.json
├── payload/
│   ├── bootstrap.lua
│   └── example/
│       └── runtime.lua
├── README.md
└── LICENSE
```

The package README and license are optional. Do not wrap these files in another directory when creating the archive.

## Minimal manifest

```json
{
  "$schema": "../../patches/schema/patch.schema.json",
  "schemaVersion": 1,
  "id": "author.example-fix",
  "version": "1.0.0",
  "name": {
    "pt-BR": "Correção de exemplo",
    "en": "Example fix",
    "es": "Corrección de ejemplo"
  },
  "description": {
    "pt-BR": "Corrige um comportamento específico no Android.",
    "en": "Fixes a specific behavior on Android.",
    "es": "Corrige un comportamiento específico en Android."
  },
  "useCases": [
    {
      "pt-BR": "O jogo fecha ao abrir o menu.",
      "en": "The game closes when opening the menu.",
      "es": "El juego se cierra al abrir el menú."
    }
  ],
  "author": "Your name",
  "category": "compatibility",
  "minimumLauncherVersion": "0.17.0",
  "priority": 100,
  "capabilities": [
    "staged_package",
    "inject_files",
    "edit_lua",
    "runtime_hook"
  ],
  "dependencies": [],
  "conflicts": [],
  "operations": [
    {
      "type": "inject",
      "source": "payload/example/runtime.lua",
      "target": "example/runtime.lua"
    },
    {
      "type": "append_text",
      "source": "payload/bootstrap.lua",
      "target": "main.lua"
    }
  ]
}
```

The authoritative format is [`patches/schema/patch.schema.json`](../patches/schema/patch.schema.json). Keep names, descriptions, and use cases available in Portuguese, English, and Spanish.

## Supported operations

### `inject`

Copies a payload file into the staged game. Existing files are protected unless `replaceExisting` is explicitly set to `true`.

```json
{
  "type": "inject",
  "source": "payload/example/runtime.lua",
  "target": "example/runtime.lua"
}
```

### `append_text`

Appends a UTF-8 payload to an existing file. This is commonly used for a small bootstrap added to `main.lua`.

```json
{
  "type": "append_text",
  "source": "payload/bootstrap.lua",
  "target": "main.lua"
}
```

### `replace_text`

Replaces an exact UTF-8 fragment. With `required: true`, staging stops when the target or search fragment is missing instead of producing a partially patched game.

```json
{
  "type": "replace_text",
  "target": "src/example.lua",
  "find": "old_call(value)",
  "replace": "android_safe_call(value)",
  "required": true
}
```

## Safety limits

- Paths must be relative, use forward slashes, and contain no `.` or `..` segments.
- Payload sources must begin with `payload/`.
- The compressed package limit is 25 MiB.
- Extracted content is limited to 75 MiB and 512 entries.
- A manifest may contain up to 64 operations and 16 use cases.
- Operation sources are limited to 10 MiB while staging a game.

## Building

Create a ZIP from inside the patch source directory, then change its extension:

```powershell
Compress-Archive -Path patch.json, payload, README.md, LICENSE -DestinationPath example-patch.zip
Move-Item example-patch.zip example-patch-1.0.0.klpatch
```

Omit optional files that are not present. Opening the resulting package should show `patch.json` immediately at its root.

Validate the manifest before importing it:

```powershell
Test-Json -Json (Get-Content -Raw patch.json) -SchemaFile ..\..\patches\schema\patch.schema.json
```

Local imports appear as unverified and are installed disabled. Test enabling and disabling the patch, launching with and without it, returning to the launcher, and confirming that the original package remains unchanged.

## Publishing in the official catalog

Place the immutable `.klpatch` archive under `patches/packages/`, calculate its SHA-256 checksum, and add its localized metadata to [`patches/catalog.json`](../patches/catalog.json).

```powershell
Get-FileHash .\patches\packages\example-patch-1.0.0.klpatch -Algorithm SHA256
```

Never replace a published package without increasing its version and updating the catalog checksum. Before publishing, verify downloads, updates from an older version, dependencies, conflicts, optional targets, required targets, and patch-disabled launches.
