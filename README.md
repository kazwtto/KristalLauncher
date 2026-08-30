<div align="center">

  <table>
    <tr>
      <td width="112" align="center">
        <img src="https://raw.githubusercontent.com/kazwtto/KristalLauncher/main/app/src/main/res/mipmap-xxxhdpi/ic_launcher_foreground.png" width="96" alt="Kristal Launcher icon">
      </td>
      <td align="left">
        <h1>Kristal Launcher</h1>
        <p>Play Kristal Engine games and mods on Android device.</p>
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
    <a href="#support-the-project">Support</a> ·
    <a href="#credits">Credits</a>
  </p>

</div>

---

## About

Kristal Launcher is a wrapper that embeds the LÖVE2D engine to run Kristal Engine games on Android.

The launcher never rewrites the package selected by the user. Every compatibility change is made to a staged copy inside the app's private storage, so a failed patch cannot damage the original `.love`, `.zip`, or fused executable.

This was originally a study project to learn Gradle and Kotlin.

## Tested Games
- [DELTARUNE: Vessel vs. Kris](https://gamejolt.com/games/dtvessel/764572)
- [DELTARUNE: PluggedDream](https://gamejolt.com/games/pluggeddream/1019739)
- [DELTARUNE: Frozen Heart](https://gamejolt.com/games/frozen-heart/659908)
- [DELTARUNE: Friendless](https://gamejolt.com/games/deltarunefriendless/1077489)
- [DELTARUNE: Frostveil](https://gamejolt.com/games/deltarune_frostveil/1058015)
  - Requires the Nil Arithmetic & Audio Sanitization patch.
- [StarRune](https://gamejolt.com/games/starrune/716680)
  - Requires the RGBA16 Conversion patch.
- [Godhome](https://gamebanana.com/mods/376524)
  - Requires the Shaders patch.
- [UNDERTALE: Cooking with Kindness](https://gamejolt.com/games/cooking_with_kindness/900285)
  - An optimization patch is under development.

## Features

- Material 3 based design.
- Patches to correct the compatibility of games designed for PC.
- Browse games in list or grid layouts, with search, favorites, and recent games.
- Launch `.love`, `.zip`, and compatible fused Windows executables `(.exe)`. Unzip is optional.
- External patches compatible (i guess, i don't test it).
- Portuguese, English and Spanish localization.

## Known Issues
- Virtual Gamepad settings are not universal. The gamepad is added directly to the game.
- Some patches do not respect the settings.
- METADATA information may not be returned.
- Zips and patches management somewhat slow. (May takes a LOT of time to load the games, sorry)

> [!NOTE]
> it's my first app like that, gimme a break-.

## Future improvements
- Add Kristal Runtime to non-excellable mods.

## Installation

Download the newest APK from [GitHub Releases](https://github.com/kazwtto/KristalLauncher/releases) and install it on a device running Android 7.0 or newer.

> [!NOTE]
> Android may ask permission to install apps from your browser or file manager. Only install APKs downloaded from this repository's official Releases page.

After opening the launcher, select the folder that contains your Kristal games. Android grants access only to that folder, and the permission can be cleared from the app settings.

## Patches

Built-in patches cover common Android differences in fullscreen behavior, GLSL ES shaders, image formats, virtual filesystems, borders, text rendering, and input. Each fix can be enabled for every game or overridden for a specific title.

See the [patch authoring guide](docs/CREATING_PATCHES.md) for the package format, supported operations, limits, and publishing workflow.

> [!NOTE]
> Can I keep all patches enabled?
>
> Yes, technically you can, patches will only act when needed (supposedly), but I wouldn't do that—I'd only enable them when necessary.

## Updates

Kristal Launcher can check this repository for new releases when the app starts. Automatic checks are optional, and a manual check is available from **Settings → About**.

Versions follow `X.Y.Z`: `X` changes for large stable updates, `Y` for smaller feature updates, and `Z` for corrections. Every APK update must advance the appropriate number and use a greater Android `versionCode`. A release is offered only when its version is newer than the app's current `versionName`, and the launcher prefers a non-debug APK whose name contains `KristalLauncher`.

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
KristalLauncher-vX.Y.Z-debug.apk
KristalLauncher-vX.Y.Z-release.apk
```

The keystore and credentials remain under the ignored `.signing/` directory. Back them up securely; Android will only accept future updates signed with the same key.

`gradlew.bat assembleDebug` compiles and checks the Android layer. Distribution APKs must use the repository build scripts because they merge `runtime/love2d/classes.dex`, align the APK, and sign the final package.

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

Patch authors should read the [patch authoring guide](docs/CREATING_PATCHES.md) before creating or publishing a `.klpatch` package.

## Project status

Kristal Launcher is under active development. Game packages and save data are important, so keep an untouched copy and report reproducible problems through [GitHub Issues](https://github.com/kazwtto/KristalLauncher/issues).

## Was Generative AI used?

Yes. ChatGPT (free-tier) was used for optimization, formatting of `.md` files, localizations for English and Spanish, and translation of README.md and code comments from Portuguese to English.

## Support the project

If Kristal Launcher is useful to you, you can support its continued development:

<p align="center">
  <a href="https://ko-fi.com/P5P0EJA8E"><img src="https://ko-fi.com/img/githubbutton_sm.svg" alt="Support Kristal Launcher on Ko-fi"></a>
  &nbsp;
  <a href="https://www.paypal.com/donate/?business=XPXE646QWFWSC&amp;no_recurring=0&amp;currency_code=BRL"><img src="https://img.shields.io/badge/Donate-PayPal-0070BA?style=for-the-badge&amp;logo=paypal&amp;logoColor=white" alt="Donate to Kristal Launcher with PayPal"></a>
</p>

## Credits

- [Kristal Engine](https://github.com/KristalTeam/Kristal) — the engine and mod ecosystem targeted by the launcher
- [LÖVE](https://love2d.org/) — the runtime used to execute games on Android

## Disclaimer

Kristal Launcher is an independent community project. It is not affiliated with or endorsed by the Kristal Engine team, LÖVE, Toby Fox, or the creators of games launched through it. Games, mods, names, and assets belong to their respective owners.
