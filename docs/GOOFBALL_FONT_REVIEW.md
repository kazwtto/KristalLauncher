# Goofball dialogue font review

## Scope

The original `priestgoofballfangame.love` installed in MuMu was inspected read-only. No original game files or fonts were changed.

## Confirmed findings

- `src/engine/game/battle/ui/speechbubble.lua` initializes battle speech bubbles with `font = options["font"] or "plain"`.
- `assets/fonts/plain.json` declares only ASCII letters, digits, spaces and punctuation. It declares no fallback font. Portuguese and Spanish accented letters are absent from its glyph list.
- No font overrides were found in the Goofball mod's actor definitions under `scripts/data/actors/`.
- Ordinary dialogue is different: `src/engine/objects/dialoguetext.lua` defaults to `main_mono`. The bitmap finding does not establish a defect in that TTF font.

Battle speech bubbles using `plain` therefore cannot display accented translation characters with the supplied font. This is a font coverage problem, not evidence that the translation was changed by a catalog refresh.

## Recommended correction

Preserve the original font as the primary font and add a fallback for unsupported characters, after verifying the fallback's glyph coverage, size and baseline. An alternative is extending the original bitmap font with matching glyphs. Do not replace every dialogue font or strip accents from translations.

The inspection confirms the missing glyphs. Launcher 0.17.53 adds the user-supplied
accented bitmap pair to all current game translation packages, staged as the selected
mod's `plain` override. The supplied bitmap was loaded and rendered with accented
text in desktop LÖVE; a complete Goofball battle playthrough remains a separate test.
See [translation font support](TRANSLATION_FONTS.md).
