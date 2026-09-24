# Basic Android TV support

The same APK exposes a Leanback launcher entry and does not require a touchscreen. The TV launcher uses the supplied `tv_banner.png` artwork. Launcher screens start with visible D-pad focus; the remote's directional and select buttons use the shared physical-input navigation described in [PHYSICAL_INPUT.md](PHYSICAL_INPUT.md).

Some Android TV builds do not provide a working `ACTION_OPEN_DOCUMENT_TREE` picker. On TV, the launcher therefore scans its own external files directory at `Android/data/kwz.love2d.launcher/files/games/`. It creates the directory on first launch and shows the exact path in the empty state and Settings. Copy `.love`, `.zip`, or `.exe` packages there and reload the library. For example, during development:

```powershell
adb push game.love /sdcard/Android/data/kwz.love2d.launcher/files/games/
```

This TV fallback is app-owned and requires no broad storage permission. On phones and tablets, the existing Storage Access Framework folder selection remains unchanged. Uninstalling the app may remove its TV game directory, so keep a separate copy of the game packages.

This is basic remote-friendly launcher support, not a full ten-foot redesign or a new gameplay-control system. The launcher does not add TV remote or gamepad bindings inside games. Validate file transfer and game compatibility on the target TV model.
