# Building

## Requirements

- JDK 17.
- Android SDK Platform 34.
- Android SDK Build Tools 34.0.0, including D8, `zipalign`, and `apksigner`.
- The checked-in Gradle Wrapper JAR.
- `runtime/love2d/classes.dex`.

Set `JAVA_HOME` and `ANDROID_HOME`, or place local toolchains under `.jdk17/jdk/` and `.android-sdk/`. These directories and `local.properties` are ignored and must not be committed.

## Project signing key

Create the Kristal Launcher keystore once:

```powershell
.\create_keystore.bat
```

This creates two ignored local files:

```text
.signing/kristal-launcher.jks
.signing/keystore.properties
```

The generator refuses to overwrite a partial or existing setup. Back up both files together in a secure location. The keystore and password are both required to publish APKs that can update an existing installation.

The final debug and release artifacts produced by the repository scripts use this project key. A previously installed APK signed with Android's standard debug key cannot be updated in place by these artifacts; uninstall that build once before installing the newly signed one.

## Commands

Compile the Android application without the post-build LÖVE2D DEX merge:

```powershell
.\gradlew.bat assembleDebug
```

Run the unit tests and Android Lint checks:

```powershell
.\gradlew.bat testDebugUnitTest lintDebug
```

Build, merge, align, sign, and verify both APK variants:

```powershell
.\build_apks.bat
```

Build only one variant:

```powershell
.\build_apk.bat
.\build_release.bat
```

Update both Android version fields:

```powershell
.\set_version.bat 0.2.0 2
```

GitHub integration URLs are centralized as `BuildConfig` fields in `app/build.gradle.kts`. Update the repository URL, API URL, and raw `patches/catalog.json` URL together if the repository owner, name, or default branch changes.

## Output

Finished APKs are moved to the ignored `artifacts/apk/` directory. Their names come from `versionName` in `app/build.gradle.kts`:

```text
artifacts/apk/KristalLauncher-v0.1.0-debug.apk
artifacts/apk/KristalLauncher-v0.1.0-release.apk
```

Gradle's intermediate APKs remain under `app/build/` and are ignored with the rest of the build directory.

## Pipeline details

For each requested variant, the build script:

1. Runs the corresponding Gradle assemble task.
2. Uses D8 to merge the application classes with `runtime/love2d/classes.dex`.
3. Replaces every `classes*.dex` entry in a temporary APK.
4. Removes obsolete JAR signature entries and runs `zipalign`.
5. Signs with `.signing/kristal-launcher.jks` through the Android SDK's official `apksigner`.
6. Verifies the signature and moves the result to `artifacts/apk/` with a versioned name.

Temporary merge files stay under `artifacts/.work/` and are removed after each variant. Signing passwords are passed to `keytool` and `apksigner` through temporary environment variables rather than command-line values.

## Troubleshooting

- A missing `GameActivity` at runtime usually means the post-Gradle DEX merge was skipped.
- A D8 error about a missing input usually means `runtime/love2d/classes.dex` or Build Tools 34.0.0 is unavailable.
- A signing error usually means `.signing/keystore.properties` and the keystore do not match.
- If only one signing file exists, restore the other from backup. Do not generate a replacement over it.
- If Gradle uses an unwritable global cache, set `GRADLE_USER_HOME` to a writable local directory for that shell.
