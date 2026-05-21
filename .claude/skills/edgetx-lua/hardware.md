# Radio Hardware Reference

Display size, color depth, and input capabilities for the radios the user cares about. Always read `LCD_W` / `LCD_H` at runtime instead of hard-coding the values below — different builds (and the simulator) can swap displays. Use this table only for *planning* layouts.

## Color / touch radios (Horus-class)

| Radio                  | Display      | Resolution | Touch | Notes                              |
| ---------------------- | ------------ | ---------- | :---: | ---------------------------------- |
| FrSky Horus X12S       | 4.3" color   | 480 × 272  | ✓     | Original color radio, capacitive   |
| FrSky Horus X10 / X10S | 4.3" color   | 480 × 272  | ✗     | Same panel, no touch               |
| FrSky Horus X10 Express| 4.3" color   | 480 × 272  | ✗     |                                    |
| RadioMaster TX16S      | 4.3" IPS     | 480 × 272  | ✓ (most variants) | The most common color radio |
| RadioMaster TX16S Mk II | 4.3" IPS    | 480 × 272  | ✓     | Hall sticks, otherwise same        |
| **RadioMaster TX16S Mk III** | **5" IPS** | **800 × 480** | **✓** | **High-res WVGA display — see Mk III notes below** |
| Jumper T16             | 4.3" color   | 480 × 272  | ✗     |                                    |
| Jumper T18             | 4.3" color   | 480 × 272  | ✓ (variant) |                              |
| RadioMaster TX12 Mk II | — see below  | — see below | — see below |                              |

All of the above use the **Horus LCD driver** in EdgeTX. Layout assumptions:
- Origin (0,0) at top-left
- Status bar at top: ~30 px (varies; treat first ~32 px as system area unless your script owns the full screen)
- Bottom area reserved for system widgets on Main View; **for telemetry/tool scripts you own the whole screen.**
- Typical widget zone heights when 2/4/6/8 widgets are tiled: roughly 90 / 60 / 40 / 30 px on 480×272 — never assume, use the `zone` table.

### TX16S Mk III notes (800 × 480)

The Mk III is currently the highest-resolution radio in this family — roughly **2.9× more pixels** than the classic 480×272 panel. Important implications for Lua scripts:

- **Hard-coded coordinates from older scripts will look tiny.** A widget written for 480×272 will only fill the top-left corner of an 800×480 screen. *Always* compute layouts from `LCD_W`/`LCD_H` and the widget `zone` — re-verified on Mk III.
- **Fonts do not auto-scale with resolution.** `SMLSIZE`/`MIDSIZE`/`DBLSIZE`/`XXLSIZE` render at the same pixel size as on the 480×272 radios, so text looks proportionally smaller on the Mk III. For headlines and primary values, prefer `DBLSIZE`/`XXLSIZE` if the script must look comparable across radios.
- **Status bar height** stays roughly the same in absolute pixels (still ~30 px), so usable area below it is larger than on 480×272 (roughly 800 × 450 vs 480 × 240).
- **Bitmap assets** designed for 480×272 will appear at their native size (not scaled). Either ship higher-resolution variants under `/IMAGES/` and pick at runtime based on `LCD_W`, or use `lcd.drawBitmap(bmp, x, y, scale)` to upscale (quality is mediocre — re-authored assets look better).
- **Touch coordinates** scale with the display — `touchState.x` / `touchState.y` can reach up to `LCD_W - 1` / `LCD_H - 1`, i.e. 799 / 479 on Mk III. Hit-test rectangles built from `zone` already work correctly; rectangles built from hard-coded pixel constants do not.
- **Performance:** the Mk III has more pixels to push, but the SoC is roughly comparable to the original TX16S. Drawing a full-screen background fill costs more here — prefer redrawing only changed regions where possible.

## Color, compact radios

| Radio                      | Display    | Resolution | Touch | Notes                                  |
| -------------------------- | ---------- | ---------- | :---: | -------------------------------------- |
| RadioMaster Boxer          | 2.8" IPS color | 480 × 320 | ✗  | Gamepad-style, IPS, no touch           |
| RadioMaster Boxer (later builds) | as above | 480 × 320 | ✗  | Same panel                             |
| RadioMaster Pocket         | 2" IPS color   | 320 × 480 | ✗  | Portrait orientation — `LCD_W=320`, `LCD_H=480` |
| Jumper T-Pro v2 (color)    | 2.4" color | 320 × 240 | ✗     | Color variant                          |

**Warning on orientation:** the RadioMaster Pocket is portrait. Always layout with `LCD_W` / `LCD_H` — a widget that hard-codes `480` for width will break.

**Warning on B/W variants of "compact" radios:** the older `Jumper T-Pro` (non-v2), `RadioMaster TX12` (Mk I), `Zorro`, etc. use **128 × 64 monochrome** displays. Lua color constants do nothing useful there, font flags are limited (`SMLSIZE`, `MIDSIZE`, `DBLSIZE`, `INVERS` only), and there is no touch. The user said "color compact" — if a script must also support these, ask explicitly before assuming.

## Quick layout helper

Use `LCD_W` and `LCD_H` plus simple ratios. Examples that adapt across all radios above:

```lua
-- Centered title
local tw, th = lcd.sizeText("STATUS", BOLD + MIDSIZE)
lcd.drawText((LCD_W - tw) / 2, 4, "STATUS", BOLD + MIDSIZE + COLOR_THEME_PRIMARY1)

-- Right-aligned value
lcd.drawNumber(LCD_W - 4, 4, batt, RIGHT + MIDSIZE + COLOR_THEME_PRIMARY1)

-- Two columns
local col2x = LCD_W / 2
```

## Capability checks at runtime

There is no first-class "is this a touch radio" API. Practical patterns:

```lua
-- Treat touchState presence as the touch test (only available in run/refresh)
local function run(event, touchState)
  if touchState then
    -- handle touch
  end
end
```

For color vs monochrome, check whether color constants exist:
```lua
local hasColor = (COLOR_THEME_PRIMARY1 ~= nil)
```

## Performance budget per radio (rough)

| Radio family   | CPU      | Realistic per-frame budget |
| -------------- | -------- | -------------------------- |
| Horus-class (TX16S, X10) | STM32F4 168 MHz | ~30 ms per refresh |
| TX16S Mk III (800×480) | STM32F4-class | ~30 ms — but full-screen fills cost more pixels; avoid clearing on every frame if possible |
| Boxer / Pocket | STM32F4  | ~30 ms                     |
| B/W compact (TX12, T-Pro) | STM32F4 | ~20 ms — leaner display, slower SD I/O |

Exceeding the budget = stutter on telemetry pages, choppy widgets, and in extreme cases the EdgeTX watchdog will halt the script.
