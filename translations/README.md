# Community translations

The launcher reads `catalog.json` to find translation packages compatible with a game's `projectId` and version. Packages are downloaded only over HTTPS, checked against the catalog SHA-256, validated, and stored in the app's private directory.

Translation targets default to the selected game or mod root. File payloads can replace Lua files in `scripts/` or JSON data files in `scripts/` and `data/`. The optional `scope: "package"` is limited to the game-owned `dialoguedump.json` and `data/i18n.json` at the staged package root. Engine, runtime, and library code paths are rejected. A package may combine `textsFile` with `files`; each target must match its original SHA-256 before replacement.
