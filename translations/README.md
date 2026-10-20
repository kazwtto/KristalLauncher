# Community translations

Font-enabled packages require launcher 0.17.53 or later. Every current package includes
the user-supplied accented `plain` bitmap pair. Fonts are hash-checked and staged only
under the selected mod's `assets/fonts/`; original packages and character-specific
fonts are unchanged. See [translation font support](../docs/TRANSLATION_FONTS.md).

The launcher reads `catalog.json` to find translation packages compatible with a game's `projectId` and version. Packages are downloaded only over HTTPS, checked against the catalog SHA-256, validated, and stored in the app's private directory.

Translation targets default to the selected game or mod root. Lua files below `scripts/` remain supported. Cooking with Kindness uses `scope: "package"` to replace only the complete package-root `dialoguedump.json` and `data/i18n.json` files. Its `ptbr` and `es` source fields become `english` in the final replacement files. Engine, runtime, and library paths are rejected.
