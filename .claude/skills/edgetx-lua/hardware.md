# Radio Hardware Reference

Display size, color depth, and input capabilities for the radios the user cares about. Always read `LCD_W` / `LCD_H` at runtime instead of hard-coding the values below: different builds (and the simulator) can swap displays. Use this table only for *planning* layouts.

## Color / touch radios (Horus-class)

| Radio                  | Display      | Resolution | Touch | Notes                              |
| ---------------------- | ------------ | ---------- | :---: | ---------------------------------- |
| FrSky Horus X12S       | 4.3" color   | 480 × 272  | ✓     | Original color radio, capacitive   |
| FrSky Horus X10 / X10S | 4.3" color   | 480 × 272  | ✗     | Same panel, no touch               |
| FrSky Horus X10 Express| 4.3" color   | 480 × 272  | ✗     |                                    |
| RadioMaster TX16S      | 4.3" IPS     | 480 × 272  | ✓ (most variants) | The most common color radio |
| RadioMaster TX16S Mk II | 4.3" IPS    | 480 × 272  | ✓     | Hall sticks, otherwise same        |
| **RadioMaster TX16S Mk III** | **5" IPS** | **800 × 480** | **✓** | **High-res WVGA display; see Mk III notes below** |
| **RadioMaster TX15**   | color        | **480 × 320** | ✓   | STM32H750, same board family as Mk III (`targets/tx15`) |
| Jumper T15             | color        | 480 × 320  | ✓     | `targets/horus`, variant `RADIO_T15` |
| Jumper T16             | 4.3" color   | 480 × 272  | ✗     |                                    |
| Jumper T18             | 4.3" color   | 480 × 272  | ✓ (variant) |                              |

Display sizes and the Touch column are manufacturer data, not verifiable in the source. The firmware for the whole Horus family (X10, X12S, T15, T16, T18, TX16S) is built with touch support (`targets/horus/CMakeLists.txt`, v2.12.4) whether or not a panel is fitted, so never assume touch: check `touchState`. TX16S Mk III and TX15 are built with `HARDWARE_TOUCH` in their own targets.

All of the above are color radios (`COLORLCD` builds). Layout assumptions:
- Origin (0,0) at top-left
- Widgets draw inside their `zone`; bar heights are scaled with the UI (see Mk III notes), so never assume them. **Tools and widgets in fullscreen mode own the whole screen.**
- Typical widget zone heights when 2/4/6/8 widgets are tiled: roughly 90 / 60 / 40 / 30 px on 480×272; never assume, use the `zone` table.

### TX16S Mk III notes (800 × 480)

The Mk III is currently the highest-resolution radio in this family: roughly **2.9× more pixels** than the classic 480×272 panel. Important implications for Lua scripts:

- **Hard-coded coordinates from older scripts will look tiny.** A widget written for 480×272 will only fill the top-left corner of an 800×480 screen. *Always* compute layouts from `LCD_W`/`LCD_H` and the widget `zone`: re-verified on Mk III.
- **Fonts do scale:** 800×480 builds ship a larger font set (`lrg`; 320×240 uses `sml`, everything else `std`; `fonts/CMakeLists.txt`, v2.12.4). Measured in the simulator (TX16S vs Mk III): heights grow by 1.29 to 1.45 depending on the font, e.g. standard 21 → 27 px, `MIDSIZE` 29 → 42 px (full table in `pitfalls.md`). The factor is not exactly `LCD_SCALE`, so always measure with `lcd.sizeText` instead of scaling heights.
- **The whole system UI is scaled by 1.375** on 800-px-wide screens (`LAYOUT_SCALE` in `gui/colorlcd/libui/etx_lv_theme.h`), header and status bars included (top bar measured 45 px on 480×272, 62 px on 800×480). Scripts can read the factor as **`lvgl.LCD_SCALE`** (1.0 at 480 px wide, 1.375 at 800, 0.8 at 320; `api_colorlcd_lvgl.cpp`) and scale paddings/sizes with it. Don't assume bar heights; lay out inside the widget `zone`.
- **Bitmap assets** designed for 480×272 will appear at their native size (not scaled). Either ship higher-resolution variants under `/IMAGES/` and pick at runtime based on `LCD_W`, or use `lcd.drawBitmap(bmp, x, y, scale)` to upscale (quality is mediocre: re-authored assets look better).
- **Touch coordinates** scale with the display: `touchState.x` / `touchState.y` can reach up to `LCD_W - 1` / `LCD_H - 1`, i.e. 799 / 479 on Mk III. Hit-test rectangles built from `zone` already work correctly; rectangles built from hard-coded pixel constants do not.
- **CPU:** Mk III and TX15 use an **STM32H750** (`targets/tx16smk3`, `targets/tx15`), much faster than the STM32F429 of the classic TX16S (`targets/horus`). The Lua limits are the same (see `pitfalls.md` → Performance limits).

**Warning on B/W radios:** `RadioMaster Boxer`, `Pocket`, `TX12` / `TX12 Mk II`, `Zorro`, `Jumper T-Pro` (incl. v2) and similar are built from the B/W `taranis` target (`targets/taranis/CMakeLists.txt`, v2.12.4) and use **128 × 64 monochrome** displays: none of them is a color radio. There are no color constants, the font flags are `SMLSIZE`, `MIDSIZE`, `DBLSIZE`, `XXLSIZE`, `BOLD`, `BLINK`, `INVERS` (`api_general.cpp`, v2.12.4), no touch and no widgets. If a script must also support these, ask explicitly before assuming.

## Quick layout helper

Use `LCD_W` and `LCD_H` plus simple ratios. Examples that adapt across the color radios above:

```lua
-- Centered title
-- (no BOLD with a size: MIDSIZE + BOLD would render as DBLSIZE, see pitfalls.md)
local tw, th = lcd.sizeText("STATUS", MIDSIZE)
lcd.drawText((LCD_W - tw) / 2, 4, "STATUS", MIDSIZE + COLOR_THEME_PRIMARY1)

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

## CPU per radio family

| Radio family | CPU (`targets/*/CMakeLists.txt`, v2.12.4) |
| --- | --- |
| TX16S, Horus X10/X12, Jumper T15/T16 | STM32F429 |
| TX16S Mk III, TX15 | STM32H750 (much faster) |

The Lua limits are the same on all of them: widgets get 20,000 instructions per call, mix/function scripts 50 ms per cycle, tools have none (see `pitfalls.md` → Performance limits).
