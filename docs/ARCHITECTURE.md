# Architecture

## Application flow

1. `MainActivity` restores the selected Storage Access Framework directory and immediately displays cached game metadata when available.
2. `GameScanner` fingerprints supported files by URI, size, and modification time. It reuses unchanged cache entries, parses changed packages with bounded concurrency, and publishes incremental results.
3. `LoveMetadataParser` accepts `.love`, `.zip`, and fused Windows `.exe` packages. It extracts size-limited Kristal `mod.json` metadata, ignores template placeholder titles such as `Example Mod`/`Exemple Mod`, and falls back to `conf.lua` or the package file name without unpacking the game permanently.
4. `GameCacheManager` stores metadata, file fingerprints, and size-limited icons for a faster next launch. Favorites and recent history use stable document URIs, with migration from older file-name keys.
5. `GameLauncher` copies the selected package into a content-addressed file under the app-private `staged/` directory. For fused executables, it first locates the embedded ZIP payload.
6. `PatchManager` rewrites only the staged ZIP. It injects global patch flags, `android_patches.lua`, and virtual-gamepad assets when enabled.
7. `GameLauncher` grants the non-exported embedded `org.love2d.android.GameActivity` read-only access to the staged file through the scoped `FileProvider`. `KristalApplication` attaches `LoveOverlayManager` while that activity is visible.

## Main components

| Component | Responsibility |
| --- | --- |
| `MainActivity` | Folder selection, navigation, search, filtering, and scan orchestration |
| `GameAdapter` | List/grid rendering, favorites, launch actions, and per-game patch settings |
| `SettingsActivity` | Appearance, language, games folder, cache, update, and compatibility navigation |
| `LanguageSettingsActivity` | Device-following or explicit app locale selection |
| `AppearanceSettingsActivity` | Device-following, light, or dark theme plus motion preferences |
| `PatchesSettingsActivity` | Patch Center for built-in, catalog, and imported patches |
| `LoveMetadataParser` | Package validation, fused executable detection, metadata, and icon extraction |
| `GameLauncher` | Staging, payload extraction, patch invocation, and native activity launch |
| `PatchManager` | Deterministic staged-ZIP patch pipeline with dependency and conflict resolution |
| `PatchStorage` | Validated external packages in application-private storage |
| `PatchCatalogService` | HTTPS catalog retrieval and offline cache |
| `PatchPackageInstaller` | Size, path, manifest, and SHA-256 validation before atomic installation |
| `UpdateChecker` | GitHub Releases update checks and local check preferences |
| `android_patches.lua` | Runtime compatibility hooks for the Kristal/LÖVE environment |
| `assets/gamepad/` | Modular virtual-controller runtime, localized settings UI, fonts, and sprite assets |

## Persistent state

Small preferences use Android `SharedPreferences`: selected folder URI, view mode, language, theme, motion, favorites, recent games, global patch flags, per-game overrides, and update-check state. Cached game metadata and icons live in application-private files, while the last valid patch catalog uses the cache directory; both may be safely cleared through their owning flows. Installed external patches live under the application-private `files/patches/` directory.

## Runtime packaging

The Gradle app contains Kotlin code, resources, and native libraries. The embedded LÖVE2D Java classes are stored separately in `runtime/love2d/classes.dex`; the Windows build scripts merge them with the Gradle-produced DEX after compilation. Removing that post-processing step creates an APK whose manifest references a missing `GameActivity`.

The native libraries in `app/src/main/jniLibs/` and the DEX runtime form one compatibility unit. Upgrade them together and test both `arm64-v8a` and `armeabi-v7a`.

## Safety invariants

- The selected source package is read-only. All rewrites target the app-private staged copy.
- ZIP entry names must be preserved unless an entry is intentionally replaced by a patch.
- Patch enablement resolves per-game override first, then the global default.
- Lua injection must happen early enough to wrap LÖVE/Kristal functions, while hooks that need initialized engine objects must defer work until `love.load`.
- Localized UI text belongs in `res/values*/strings.xml`, never directly in Kotlin or layout runtime attributes.

## Remaining risks

- Unit tests cover semantic version ordering, archive-path validation, and safe Lua-footer placement. ZIP rewriting, executable payload detection, and runtime shader behavior still need broader automated coverage.
- Runtime Lua compatibility depends on Kristal internals that can change between engine releases.
- Runtime DEX merging is Windows-oriented and depends on a local Android SDK plus a separate signing helper.
- Patch-list refreshes still redraw the complete catalog; this is small today but should use an asynchronous differ if the official catalog grows substantially.
- Storage Access Framework provider performance varies by device. The incremental cache avoids rereading unchanged packages, but initial indexing still depends on provider throughput.
