# Repository audit

## Summary

The initial working tree mixed the Android application with downloaded toolchains, extracted APKs, complete game packages, temporary merge output, copied engine sources, one-off diagnostic scripts, duplicated artwork, and overlapping historical reports. The tracked tree contained 3,364 files; 2,492 were under `tools/`, 424 under `.love_dex/`, and 137 under `.love_only/`. Tracked games and extracted diagnostic material accounted for most of the repository size.

The maintained product is much smaller: Android source/resources, Lua compatibility assets, native LÖVE2D libraries, one Java runtime DEX, build scripts, store artwork, and focused documentation.

## Retained inputs

- `app/`: application source, resources, Lua injection assets, and required native libraries.
- `runtime/love2d/classes.dex`: required Java side of the embedded LÖVE2D runtime.
- `artwork/play-store-icon.png`: non-duplicated publishing artwork.
- Gradle wrapper files and portable project settings.
- Windows build/version helpers.
- Architecture, build, compatibility, and repository guidance.

## Material marked for removal

- Extracted APK trees: `.love_dex/` and `.love_only/`.
- The old hidden runtime staging folder after its required DEX was copied to `runtime/love2d/`.
- `tools/`, including a complete copied Kristal tree and one-off investigation material.
- `scripts patches/`, which duplicates the gamepad assets bundled under `app/src/main/assets/`.
- Test game packages and their extracted workspaces.
- Historical Portuguese reports whose maintained findings are consolidated in the current English documentation and patch comments.
- Duplicate launcher icon exports after retaining the Play Store source image.
- Scratch Lua files, temporary archives, extracted APKs, and build merge output.

## Configuration findings addressed

- Removed a machine-specific JDK path from shared Gradle properties.
- Stopped ignoring the required Gradle Wrapper JAR.
- Added explicit line-ending and binary-file rules.
- Made the Windows wrapper honor `JAVA_HOME`, fall back to the repository-local JDK, and use the normal per-user Gradle cache.
- Made build helpers validate required SDK, runtime, and signing inputs.
- Moved hardcoded runtime UI messages into synchronized Portuguese, English, and Spanish resources.
- Replaced the stale hardcoded About version with `BuildConfig.VERSION_NAME`.
- Fixed DEX packaging so every old `classes*.dex` entry is removed before the unified runtime DEX is inserted.

## Remaining risks

- Unit tests now cover semantic version ordering, safe archive paths, template-title handling, fused-executable payload detection, and Lua footer placement. Full ZIP rewrites, shader behavior, and native launch flows still need broader automated and device coverage.
- The checked-in DEX and native libraries have no repository-level provenance/version manifest. Add their upstream version, source URL, license, and checksum before distributing releases.
- Debug and release artifacts are signed with the project's ignored local keystore through the Android SDK's official `apksigner`; the keystore and credentials still require an external secure backup.
- Runtime validation still requires manual tests on Android hardware with representative `.love`, `.zip`, and fused `.exe` packages.
