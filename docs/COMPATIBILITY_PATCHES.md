# Compatibility patches

Compatibility patches are configured globally and may be overridden per game. `PatchManager` serializes the effective flags into the staged package and injects the Lua support files. The user's original package is never modified.

The Patch Center also supports external `.klpatch` packages. Verified packages are listed in `patches/catalog.json` and stored under `patches/packages/` in the GitHub repository. Users may import local packages, which are marked unverified and installed disabled.

Patch cards keep their primary descriptions brief. Built-in fixes and external manifests can provide localized use cases, shown separately through the **When it helps** action. External packages declare these as an optional `useCases` array of localized strings.

## Official extra patches

| Patch | Purpose | Main limitation |
| --- | --- | --- |
| Kristal Engine in Brazilian Portuguese (`kristal.ptbr`) | Translates built-in engine text and overlays translated interface sprites | Mod-specific dialogue is translated only when it exactly matches a known engine string |

The KristalPT package source is stored under `patches/sources/kristal-ptbr/`, and its published archive is stored under `patches/packages/`. It uses only the existing `inject` and `append_text` operations: the package adds a Lua runtime translator, appends a small bootstrap to the staged `main.lua`, and overlays 51 translated sprites. Static mappings and `{luaN}` placeholders are converted into exact and dynamic runtime rules when the package is built.

## Available patches

| Patch | Purpose | Main risk |
| --- | --- | --- |
| Accumulated text | Recreates/clears affected Kristal text canvases | Disabling it may allow old text to remain on screen |
| Immersive fullscreen | Keeps Android system bars hidden | Changes expected window behavior |
| GLSL ES shader fixes | Applies narrowly detected shader transformations | A transformation may alter a shader that relied on desktop behavior |
| Virtual gamepad | Injects touch controls and sprites | May overlap a game's own controls |
| Relative borders | Resizes/mirrors Kristal borders for wide displays | Engine-version-specific drawing assumptions |
| RGBA16 conversion | Converts unsupported high-bit-depth image data | Additional load-time work |
| PhysFS recursion guard | Replaces recursive virtual file walks with an iterative, cycle-aware traversal | Very large virtual trees still take time to enumerate |
| Nil/audio sanitization | Adds defaults around missing numeric/audio state | Changes fallback behavior for malformed mod state |

The virtual gamepad is copied from `app/src/main/assets/gamepad/` into the staged package. Its settings menu follows the launcher's effective Portuguese, English, or Spanish locale and receives the active Material primary color when the staged copy is generated. Locale or theme changes are part of the staged-package fingerprint so an outdated controller UI is not reused.

## Shader transformation rules

The shader patch is intentionally detection-driven. Each transformation first checks whether its target syntax is present. Current rules handle the GLSL 3 reserved identifier `sample`, LÖVE's `number` alias, selected integer literals passed to float functions, color-channel comparisons with integer literals, problematic `mod()` calls, and initializers on `uniform`/`extern` declarations.

Keep transformations independent and fail-open: if one transformation throws or returns an invalid result, retain the previous shader text and continue. Do not apply broad arithmetic substitutions across an entire shader; array sizes, loop counters, and indexes must remain integers.

## Changing a patch

1. Confirm whether the change belongs in Kotlin ZIP rewriting or in runtime Lua hooks.
2. Preserve all unrelated ZIP entries and timestamps where practical.
3. Make detection as narrow as the failing pattern permits.
4. Verify the game starts with the patch enabled and disabled.
5. Test a game that does not contain the target pattern to guard against regressions.
6. Update all localized patch descriptions when behavior or risk changes.

## External package safety

- Packages must use schema version 1 and contain `patch.json` at the archive root.
- Archive paths are rejected when absolute, traversal-based, backslash-based, or otherwise unsafe.
- Package and expanded sizes, entry counts, operation counts, and text sizes are limited.
- Catalog downloads require HTTPS and must match the SHA-256 recorded in the catalog.
- Imported packages remain unverified and require explicit confirmation before activation.
- Operations are restricted to staged-package file injection and deterministic UTF-8 text edits.
- The completed staged ZIP is validated before replacing the previous staged copy; replacement uses a rollback file.

See `patches/README.md` and `patches/schema/patch.schema.json` for the package format and publishing workflow.
