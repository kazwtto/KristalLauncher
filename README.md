<div align="center">

  <table>
    <tr>
      <td width="112" align="center">
        <img src="https://raw.githubusercontent.com/kazwtto/KristalLauncher/main/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png" width="96" alt="Kristal Launcher icon">
      </td>
      <td align="left">
        <h1>Kristal Launcher</h1>
        <p>An Android launcher for games and mods made with Kristal Engine.</p>
      </td>
    </tr>
  </table>

  <p>
    <a href="https://www.android.com/"><img src="https://img.shields.io/badge/Android-7.0%2B-3DDC84?logo=android&amp;logoColor=white" alt="Android 7.0+"></a>
    <a href="https://kotlinlang.org/"><img src="https://img.shields.io/badge/Kotlin-1.9.23-7F52FF?logo=kotlin&amp;logoColor=white" alt="Kotlin 1.9.23"></a>
    <a href="https://m3.material.io/"><img src="https://img.shields.io/badge/Material-3-6750A4?logo=materialdesign&amp;logoColor=white" alt="Material 3"></a>
    <a href="https://github.com/kazwtto/KristalLauncher/releases"><img src="https://img.shields.io/github/v/release/kazwtto/KristalLauncher?display_name=tag&amp;sort=semver" alt="Latest GitHub release"></a>
  </p>

  <p>
    <a href="#features">Features</a> ·
    <a href="#installation">Installation</a> ·
    <a href="#patches">Patches</a> ·
    <a href="#building">Building</a> ·
    <a href="#credits">Credits</a>
  </p>

</div>

---

## About

Kristal Launcher keeps a local library of Kristal Engine games on Android. It reads package metadata, prepares a private Android-ready copy, applies optional compatibility patches, and starts the game with an embedded LÖVE2D runtime.

The launcher never rewrites the package selected by the user. Every compatibility change is made to a staged copy inside the app's private storage, so a failed patch cannot damage the original `.love`, `.zip`, or fused executable.

## Features

- Scan a folder selected through Android's system document picker
- Read game titles, subtitles, versions, authors, and icons from Kristal packages
- Browse games in list or grid layouts, with search, favorites, and recent games
- Launch `.love`, `.zip`, and compatible fused Windows executables
- Enable Android compatibility fixes globally or override them for one game
- Use a configurable virtual gamepad with localized settings
- Download verified extra patches or import a local `.klpatch` package
- Follow the device language and theme, or choose Portuguese, English, Spanish, light, or dark manually
- Reduce interface motion from the appearance settings
- Check GitHub Releases automatically or on demand

## Installation

Download the newest APK from [GitHub Releases](https://github.com/kazwtto/KristalLauncher/releases) and install it on a device running Android 7.0 or newer.

> [!NOTE]
> Android may ask permission to install apps from your browser or file manager. Only install APKs downloaded from this repository's official Releases page.

After opening the launcher, select the folder that contains your Kristal games. Android grants access only to that folder, and the permission can be cleared from the app settings.

## Patches

Built-in patches cover common Android differences in fullscreen behavior, GLSL ES shaders, image formats, virtual filesystems, borders, text rendering, and input. Each fix can be enabled for every game or overridden for a specific title.

The Patch Center also supports external `.klpatch` packages. Packages downloaded from this repository are verified against the SHA-256 value in [`patches/catalog.json`](patches/catalog.json); local imports are labeled unverified and remain disabled until the user enables them. The first official extra is a Brazilian Portuguese localization patch based on KristalPT.

See the [patch authoring guide](patches/README.md) for the package format, supported operations, limits, and publishing workflow.

## Updates

Kristal Launcher can check this repository for new releases when the app starts. Automatic checks are optional, and a manual check is available from **Settings → About**.

Release tags should use semantic versions such as `v0.2.0`. A release is offered only when its version is newer than the app's current `versionName`, and the launcher prefers a non-debug APK whose name contains `KristalLauncher`.

## Building

### Requirements

- JDK 17
- Android SDK Platform 34
- Android SDK Build Tools 34.0.0
- Git

Clone the repository:

```bash
git clone https://github.com/kazwtto/KristalLauncher.git
cd KristalLauncher
```

On Windows, create the project signing key once and build both variants:

```powershell
.\create_keystore.bat
.\build_apks.bat
```

Finished APKs are written to the ignored `artifacts/apk/` directory with versioned names:

```text
KristalLauncher-v0.1.0-debug.apk
KristalLauncher-v0.1.0-release.apk
```

The keystore and credentials remain under the ignored `.signing/` directory. Back them up securely; Android will only accept future updates signed with the same key.

`gradlew.bat assembleDebug` compiles and checks the Android layer. Distribution APKs must use the repository build scripts because they merge `runtime/love2d/classes.dex`, align the APK, and sign the final package. See [the full building guide](docs/BUILDING.md) for details.

## Tech stack

| Area | Technology |
| --- | --- |
| Language | Kotlin 1.9.23 and Lua |
| Android UI | Material 3, AppCompat, XML layouts, RecyclerView |
| Async work | Kotlin coroutines and Android lifecycle scopes |
| File access | Storage Access Framework and DocumentFile |
| Runtime | Embedded LÖVE2D native libraries and Java DEX |
| Build | Gradle Kotlin DSL and PowerShell packaging scripts |

## Project structure

| Path | Purpose |
| --- | --- |
| `app/` | Android source, resources, native libraries, and Lua runtime assets |
| `runtime/love2d/` | Java DEX paired with the checked-in LÖVE2D native libraries |
| `patches/` | Patch catalog, schemas, published packages, and editable sources |
| `scripts/` | APK packaging, signing, and repository maintenance helpers |
| `docs/` | Architecture, compatibility, build, and audit notes |

Read [the architecture notes](docs/ARCHITECTURE.md) before changing launch or staging, and [the compatibility notes](docs/COMPATIBILITY_PATCHES.md) before changing patch behavior.

## Project status

Kristal Launcher is under active development. Game packages and save data are important, so keep an untouched copy and report reproducible problems through [GitHub Issues](https://github.com/kazwtto/KristalLauncher/issues).

## Credits

- [Kristal Engine](https://github.com/KristalTeam/Kristal) — the engine and mod ecosystem targeted by the launcher
- [LÖVE](https://love2d.org/) — the runtime used to execute games on Android
- KristalPT — source text and interface graphics used by the Brazilian Portuguese extra patch

## Disclaimer

Kristal Launcher is an independent community project. It is not affiliated with or endorsed by the Kristal Engine team, LÖVE, Toby Fox, or the creators of games launched through it. Games, mods, names, and assets belong to their respective owners.
