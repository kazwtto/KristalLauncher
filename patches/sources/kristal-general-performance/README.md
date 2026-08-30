# Kristal general performance optimization

This development patch is designed for multiple Kristal revisions. It does not replace engine source text. Instead, it injects a small runtime hook and appends a bootstrap to `main.lua`.

The hook skips only 1 ms-or-shorter sleeps while the game runs on Android or with VSync enabled. It also gives compatible Kristal canvas pools a 120-frame grace period before their original cleanup can evict unused canvases, reducing GPU reallocation without retaining canvases forever.

Every hook is capability-checked and otherwise becomes a no-op. The patch does not modify game content or the original archive; it operates only on Kristal Launcher's staged copy.

Kristal Launcher normalizes supported archives to expose `main.lua` at the staged root before this patch is applied.

This is an experimental compatibility patch. It is safe to enable across supported packages, but FPS gains cannot be guaranteed because they depend on the game, mod, renderer, scene, and device. Test with and without it on the target device.
