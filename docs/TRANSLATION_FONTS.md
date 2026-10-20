# Translation bitmap fonts

Community translation manifests may declare a `fonts` array containing the paired
`fonts/plain.png` and `fonts/plain.json` payloads, each with its SHA-256. This does
not grant access to arbitrary asset or engine paths. The installer validates the
pair, hashes, size, PNG signature and metadata. Old manifests without fonts remain
supported. Font-enabled packages require launcher 0.17.53 or later.

The selected translation stages the pair under the metadata-selected mod root's
`assets/fonts/`, overriding Kristal's `plain` font through its normal asset loader.
Existing entries are replaced; absent entries are added once. Original game files,
Lua identifiers, dialogue tags and character-specific fonts are not rewritten.
Disabling the translation omits its fonts; package hashes invalidate staged caches
when the font changes. Conflicting external operations on the same paths are rejected.

The supplied source is `plain_ptbr_es_kristal_atualizado.zip` (provided by the user).
It contains 158 mapped glyphs, including `¡¿«»ªº°€—–…`. Its PNG and
JSON are copied unmodified. The archive's notice describes the added accented
glyphs as manually drawn, unofficial additions. These assets are a temporary font
choice, not a claim that they exactly reproduce each game's original typography.

Current Portuguese and Spanish game translations include the pair. The Portuguese
and Spanish engine patches overlay it at `assets/fonts/plain.*`. This supplied font
is restricted to Portuguese and Spanish translations. The Russian engine patch is
unchanged and does not include this font or a Latin fallback.
