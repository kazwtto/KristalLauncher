# Creating patches for Kristal Launcher

A `.klpatch` is a small ZIP package that describes changes to a game's staged copy. It can add files, append UTF-8 text, or replace an exact UTF-8 fragment. It cannot run commands, access the original game file, or write outside the staged package.

Use an external patch when a fix or optional feature can be expressed as files and deterministic text edits. Changes to the launcher itself, Android lifecycle handling, or ZIP staging belong in the Kotlin code instead.

## Package layout

`patch.json` must be at the archive root. Files referenced by operations must be under `payload/`.

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

`README.md` and `LICENSE` are recommended but optional. They are installed with the package for reference and are not copied into the game.

## A minimal manifest

```json
{
  "$schema": "../../schema/patch.schema.json",
  "schemaVersion": 1,
  "id": "example.mobile-fix",
  "version": "1.0.0",
  "name": {
    "pt-BR": "Correção móvel de exemplo",
    "en": "Example mobile fix",
    "es": "Corrección móvil de ejemplo"
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
  "minimumLauncherVersion": "0.1.0",
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

The authoritative format is [schema/patch.schema.json](schema/patch.schema.json). Keep localized patch names, descriptions, and use cases in Portuguese, English, and Spanish so the Patch Center does not fall back to another language.

## Manifest fields

| Field | Meaning |
| --- | --- |
| `schemaVersion` | Package format version. The current value is `1`. |
| `id` | Stable lowercase identifier with at least one separator, such as `author.patch-name`. |
| `version` | Package version. Publish a new version instead of replacing an installed one. |
| `name` | Short display name, either a string or a localized object. |
| `description` | Brief explanation shown on the patch card. |
| `useCases` | Optional list of concrete symptoms shown under **When it helps**. |
| `author` | Person or group maintaining the patch. |
| `category` | Free-form grouping such as `compatibility`, `localization`, or `controls`. |
| `minimumLauncherVersion` | Oldest launcher version that can install the package. |
| `priority` | Application order; lower values are processed first. Dependencies are always processed before their dependants. |
| `capabilities` | Declares the kind of changes requested by the package. |
| `dependencies` | Patch IDs that must also be enabled. |
| `conflicts` | Patch IDs that cannot be enabled at the same time. |
| `operations` | Ordered list of changes applied to the staged game. |

Supported capabilities are `staged_package`, `inject_files`, `edit_lua`, and `runtime_hook`. An `inject` operation requires `inject_files`; `append_text` and `replace_text` require `edit_lua`. Only declare `runtime_hook` when the injected Lua remains active while the game runs.

## Operations

### `inject`

Copies a file from `payload/` into the staged package.

```json
{
  "type": "inject",
  "source": "payload/example/runtime.lua",
  "target": "example/runtime.lua"
}
```

An inject cannot overwrite an existing game entry unless `replaceExisting` is explicitly set to `true`. Two enabled patches cannot both inject the same target.

### `append_text`

Appends a UTF-8 payload file to an existing staged file. It is commonly used to add a small bootstrap to `main.lua`.

```json
{
  "type": "append_text",
  "source": "payload/bootstrap.lua",
  "target": "main.lua"
}
```

Set `required` to `false` if the patch may safely continue when the target is absent. It defaults to `true`.

### `replace_text`

Replaces every exact occurrence of a UTF-8 fragment. Keep the search text narrow enough to avoid unrelated code and stable enough to survive harmless formatting changes.

```json
{
  "type": "replace_text",
  "target": "src/example.lua",
  "find": "old_call(value)",
  "replace": "android_safe_call(value)",
  "required": true
}
```

With `required: true`, staging stops if the target file or search fragment is missing. This is safer for version-specific rewrites because the game will not start in a partially patched state.

## Paths and limits

Archive and operation paths must be relative, use forward slashes, and contain no drive letters, backslashes, empty segments, `.` segments, or `..` traversal. Payload sources must begin with `payload/`.

The installer currently enforces these limits:

- 25 MiB compressed package size.
- 75 MiB total extracted size.
- 512 archive entries.
- 256 KiB manifest size.
- 64 operations and 16 use cases.
- 240 characters per archive path.
- 10 MiB per operation source when a game is staged.

These checks are part of the application as well as the JSON schema. A package that passes a desktop schema validator can still be rejected if it exceeds an application limit or requests an unsupported capability.

## Building a package

From the patch source directory, create a ZIP with `patch.json` at its root, then change only the archive extension:

```powershell
Compress-Archive -Path patch.json, payload, README.md, LICENSE -DestinationPath example-patch.zip
Move-Item example-patch.zip example-patch-1.0.0.klpatch
```

Omit `README.md` or `LICENSE` from the command if the package does not contain them. Do not zip the parent directory. Opening the archive should show `patch.json` immediately, not `example-patch/patch.json`.

Validate the manifest against the checked-in schema:

```powershell
Test-Json -Json (Get-Content -Raw patch.json) -SchemaFile ..\..\schema\patch.schema.json
```

Then import the `.klpatch` through the Patch Center. Local imports are intentionally marked unverified and installed disabled.

## Publishing in the official catalog

Official packages are stored under `patches/packages/`. After building the archive, calculate its checksum:

```powershell
Get-FileHash .\packages\example-patch-1.0.0.klpatch -Algorithm SHA256
```

Add an entry to [catalog.json](catalog.json) with the same ID, version, localized metadata, capabilities, a package path relative to the catalog, and the lowercase SHA-256 value. Catalog downloads use HTTPS and are accepted only when the downloaded file matches that checksum.

Do not change a published archive without changing its version and catalog hash. Keeping releases immutable makes cached catalogs and installed versions predictable.

## Testing checklist

Before publishing, test all of the following:

1. Import or download the package and confirm its metadata is shown in all three languages.
2. Enable it globally and launch a game that needs the patch.
3. Disable it for the same game and confirm the unpatched staged copy is rebuilt.
4. Launch a game that does not contain the target pattern.
5. Check missing optional and required targets.
6. Test dependencies, conflicts, and collisions with other patches when used.
7. Return to the launcher and launch again to catch stale staging-cache behavior.
8. Confirm the original game package has not changed.

## Packages maintained here

`kristal.ptbr` is the first official extra patch. Its editable source is under `sources/kristal-ptbr/`, while the published archive is under `packages/`. The source build script converts the KristalPT 2.3.1 translation maps into a Lua lookup table, includes the translated interface graphics, writes the manifest, and creates the `.klpatch` archive.
