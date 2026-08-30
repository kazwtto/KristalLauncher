# Cooking with Kindness mobile and battle optimization

This external patch targets the `Cooking with Kindness DEMO v1.0.6` package built on Kristal `v0.10.0-dev`.

## What it changes

- Replaces `beeglighttest.lua`: it no longer allocates and composites a canvas matching the full map. The original CORE Square canvas is 1920 x 1800 pixels; the replacement draws the small light set directly into the active world target.
- Replaces `lighttest.lua`: it no longer creates an unused screen-sized canvas for every light, and it does not run an extra update from `draw()`.
- Replaces `betterlayering.lua`: it removes two debug-console writes that would otherwise happen every frame per event.
- Defers the engine canvas-pool cleanup and skips the demo's redundant 1 ms frame sleep on Android.
- Replaces the customer-battle timer to retain its `love.graphics.Text` object instead of allocating one every frame. The display changes only when the integer timer changes.
- Removes a duplicate timer update in customer encounters. This affects the Grillby tutorial and every regular customer battle.
- Removes per-frame debug logging and redundant `setSprite()` calls from the standard and Toriel whisk and oven minigames.
- Removes remaining debug logging from the Toriel catch tutorial and customer encounter flow.

The patch changes only the launcher's staged copy. The source game package is never modified.

## Compatibility

The file paths and mod ID are specific to the bundled `Cooking with Kindness DEMO v1.0.6`. The runtime hook activates only when Kristal loads the `cooking-with-kindness` mod. Do not enable this together with the general Kristal performance patch, because this package already includes the overlapping loop and canvas-pool safeguards.
