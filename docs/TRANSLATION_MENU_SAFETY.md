# Translation menu safety

## Problem and chosen design

Kristal uses an ACT name both as its visible label and as the selector passed to
`onAct`, `onShortAct`, `getAct`, and `removeAct`. Renaming only the registration
breaks dispatch and can leave a battle waiting forever. The same problem affects
shop talk topics and JSON-backed `_s` registrations in Cooking with Kindness.

The launcher keeps canonical selectors from the original game. A separate weak
table stores translated presentation labels per owner instance and menu family.
The renderer reads those labels when drawing and measuring text. Comparisons,
callbacks, flags, registration tables, and saved selectors retain their originals.
No reverse mapping of translated strings is used.

## Preparation pipeline

1. Validate source hashes and source expressions as before.
2. Lex the original Lua, masking strings and comments before finding registration
   arguments. Protect ACT, Short ACT, character-specific ACT, shop registration,
   replacement topics, and static `getXAction` returns.
3. Convert a translated static selector into a call to the presentation module.
   That call records its label and returns the original selector.
4. For `dialoguedump.json`, compare hash-verified original and replacement English
   values. Resolve `_s` keys at protected registrations within the selected mod's
   `scripts/` directory. Normal dialogue lookups keep using the replacement JSON.
   Marked dynamic JSON expressions are evaluated with the game's own
   `Kristal.UnconcateText` and original variable arguments. Their canonical
   evaluated value remains the selector, not the encoded expression. Translated
   expressions must preserve their executable structure; malformed expressions
   fall back to the original label for that action.
5. After external patch operations, protect JSON-backed registrations again and
   adapt the standard dark battle, Magical Glass light battle, and shop renderers.
6. Prepend the presentation bootstrap to the staged `main.lua` before any game
   module can register an action, including games that initialize at module load.
7. Include the safety revision in the translation cache fingerprint so previously
   prepared games are rebuilt without changing their original packages.

Control tags retain their executable arguments (including callback names), and
dynamic `{luaN}` placeholders retain their order and identity. Multi-argument
reaction tags allow translating their first, visible-text argument while preserving
coordinates, face, and actor. Unknown bracketed prose is not treated as a command.

## Existing packages and projects

Protection runs when applying translations, not just when extracting them. Existing
text-only packages, local projects, and the existing Cooking file replacements
benefit without repacking or discarding translations. Community packages continue
to contain their translation data; the presentation implementation belongs to the
launcher and is injected only into the private staged copy.

Dynamic selectors that cannot be resolved safely remain original. Conflicting
translations from different owners are not merged into a global dictionary.
Values used in comparisons, dispatch-table keys, and ACT/talk lookups are protected
when an ambiguous choice or field shares that value. Explicit dialogue display calls
remain translatable even when their prose happens to match a selector.
Custom UI implementations that do not use the standard renderer may retain original
labels; canonical action dispatch still takes priority over guessing their behavior.

## Verification

- JVM tests cover static and JSON-backed registrations, descriptions, comments,
  long strings, character-specific short ACTs, shop topics, X-Actions, and dynamic
  selectors.
- Optional original-game audit inputs: `KL_TRANSLATION_AUDIT_GAME` for Plugged Dream
  and `KL_TRANSLATION_AUDIT_COOKING` for Cooking with Kindness. These validate the
  published replacements against original game data and emit ignored Lua fixtures.
- `translations/verify_menu_labels.py` executes those fixtures with Lua 5.1 and
  LuaJIT through `lupa`, checking dispatch completion, removal, dynamic registration,
  owner isolation, ambiguous labels, and syntax.
- `OfflineTranslationReviewTest` creates private desktop `.love` copies in
  `artifacts/translation-review`, using the published packages and the same
  translation functions without running Android. It checks package/source hashes,
  replacement targets, unchanged originals, and ZIP integrity.
- `translations/review_applied_games.py` compares unchanged archive entries,
  compiles all changed Lua scripts, reproduces the unprotected dispatch failure,
  and executes actual Romb, Catamari, and Mawzz callback modules in Lua 5.1 and
  LuaJIT with graphic/audio services stubbed. It also validates the compilation
  of translated Cooking JSON expressions and saves any package defects separately.
- `translations/verify_android_regex.py` checks constant Kotlin regex patterns
  with ICU on Windows. Java's regex accepts an unmatched closing brace which
  Android's ICU rejects; the dynamic `{luaN}` pattern escapes both braces.
- Device acceptance: open translated games with other patches enabled and disabled;
  select normal and short ACTs; exercise unlock/removal of ACTs, X-Actions, shop
  topics, battle completion, and return to the launcher.
