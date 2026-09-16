# Community translations

The launcher reads `catalog.json` to find translation packages compatible with a game's `projectId` and version. Packages are downloaded only over HTTPS, checked against the catalog SHA-256, validated, and stored in the app's private directory.

Translation targets are relative to the selected game or mod root. The current package format accepts only Lua files below `scripts/`; engine, runtime, and library paths are rejected.
