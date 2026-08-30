# Kristal Engine — Portuguese (Brazil)

This package contains the Brazilian Portuguese translation data and graphics maintained for the Kristal Launcher external-patch format.

The patch installs a runtime translation module into the staged game, hooks Kristal's `Text`, `DialogueText`, `Draw`, and LÖVE text entry points, and overlays the translated interface sprites. Static strings and `{luaN}` dynamic placeholders from the source translation maps are supported.

The original game package is never changed. Mod-specific dialogue is outside the patch's scope unless it exactly matches a translated engine string.

The runtime lookup is case-sensitive, matching Lua string behavior. A source key that has multiple different translations across categories is intentionally omitted because a runtime text hook cannot reliably recover the source category.

## Source maintenance

- Translation source maps live under `source-text/`.
- Runtime files and translated sprites live under `payload/`.
- Run `build.ps1` to regenerate `payload/kristal_pt/translations.lua`, `patch.json`, and the `.klpatch` archive.
