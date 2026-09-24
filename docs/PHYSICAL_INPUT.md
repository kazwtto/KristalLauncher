# Physical keyboard and controller input

Launcher screens extend `ControllerNavigationActivity`. It makes clickable controls focusable, follows newly attached `RecyclerView` rows, translates the left stick and hat axes into focus movement, and draws a theme-colored focus outline while physical navigation is active. Touch input hides the outline. The Android focus system remains responsible for choosing the next visible view and scrolling lists.

| Action | Keyboard | Controller |
| --- | --- | --- |
| Move focus | Arrow keys / D-pad | D-pad or left stick |
| Activate | Enter / Space | A / Cross |
| Back | Escape / Backspace outside text fields | B / Circle |
| Switch Home or game-detail tabs | Page Up/Down or Ctrl+Left/Right | L1/R1 |
| Open a focused game's More menu | Menu or Shift+F10 | X / Square |

Escape or B first leaves a focused text field and hides the software keyboard. Arrow keys inside a text field keep their normal cursor behavior. The left stick has a 0.55 deadzone and a 220 ms repeat interval. Hat axis events arriving immediately after an equivalent D-pad key are ignored to prevent a double move.

`LoveOverlayManager` handles the launcher menu over `GameActivity`. Android Back, Ctrl+Escape, or a controller's Guide/Mode button opens it. D-pad or left stick chooses Resume or Exit; Enter/Space/A confirms, and Escape/B closes the menu. Escape and Start otherwise reach the game, because Kristal uses them as gameplay/menu inputs. When the overlay is visible, it consumes keyboard and controller navigation so the game cannot act on menu presses.

The embedded LÖVE runtime receives keyboard and controller events directly while the overlay is closed. The launcher does not convert physical controller input to touchscreen input or change a game's own bindings. Controller recognition therefore depends on Android and the LÖVE runtime's SDL mapping for that device.

Verification should include a complete touch-free trip through Home, game details, settings, runtime and patch lists, translation editor, gameplay, and the overlay. ADB `input keyevent` can exercise keyboard, D-pad, and gamepad button paths; analog-stick, hot-plug, and device-specific mappings need a physical controller or a test device able to send `MotionEvent` joystick axes.
