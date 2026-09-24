# Detecting Kristal Launcher

Kristal games and mods can detect a launch from Kristal Launcher through the engine's existing `Kristal.getModOption` method. The launcher does not add a global or a new method.

```lua
if Kristal.getModOption("kristalLauncher") then
    -- The game is running from Kristal Launcher.
end
```

Detailed information is available through the only additional reserved option:

```lua
local info = Kristal.getModOption("kristalLauncher.info")
```

`info` has the following shape:

```lua
{
    name = "Kristal Launcher",
    version = "0.17.48",
    versionCode = 65,
    apiVersion = 1,
    platform = "Android",
    game = {
        packageType = "mod", -- or "executable"
        isKristalMod = true,
        version = "1.0.0",
        engineVersion = "0.10.0-dev"
    },
    runtime = {
        tag = "v0.10.0",
        version = "0.10.0"
    },
    patches = {
        enabled = true,
        active = { "patch_fullscreen" }
    },
    translation = {
        enabled = true,
        language = "pt-BR"
    }
}
```

`runtime` is `nil` for executable packages that do not use a launcher-managed Kristal runtime. Optional game and translation values can also be `nil`.

All other option names are delegated unchanged to Kristal's original `getModOption` implementation. Detection is available before the mod scripts are loaded and remains present when compatibility patches and translations are disabled.
