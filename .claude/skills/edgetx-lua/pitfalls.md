# Common Pitfalls & Constraints

EdgeTX Lua is **not** standard Lua 5.x: it is a stripped-down sandbox running on a microcontroller. Most "weird" bugs come from violating one of the constraints below. Entries with a source note (`file.cpp`, version) are verified against the EdgeTX source; see `SKILL.md` → Source of truth.

## Silent script load failures

These will make your script seem to "not exist" without any error:

- **Telemetry / Mix / Function script filename > 6 chars** (without `.lua`). EdgeTX silently skips files with longer base names. `telemetry.lua` → reject. `mytlm.lua` → ok.
- **Widget `name` field too long**: EdgeTX 2.11 stores it in a 20-char field (`widgets_container.h`), a longer name is cut and the widget is likely not found after a reload; 2.12 has no limit. (The often quoted 10-char limit is from the 2.10 docs.) Keep names ≤ 20 chars.
- **Widget option name > 10 chars or contains a space** on EdgeTX 2.10 (per docs). Whole `options` array is rejected → widget loads but is unconfigurable. 2.11+ does not check either (verified in source); keep names space-free anyway, see script-types.md.
- **Too many widget options**: max 5 on 2.10, 10 on 2.11, 50 on 2.12. Extra options are silently dropped.
- **Mix script with more than 6 inputs or outputs**: the extra ones are silently ignored. Names are cut to 6 chars (outputs always; inputs only on 2.11), not rejected.

## Wrong value ranges

- Mix-script **`VALUE` inputs** use their own min..max (16-bit, default -100..+100 if omitted), not the ±1024 channel range. `SOURCE` inputs deliver ±1024.
- **`BOOL` widget options are 0 or 1**, not Lua booleans (`lua_widget.cpp`, v2.12.4; confirmed in the TX16S MK3 simulator: unchecked = 0 and truthy). In Lua **0 is truthy** (only `nil` and `false` are false), so `if widget.options.MyBool then` is **always true**, and `== true` is always false. Always compare `== 1`.
- **Switch sources** return tri-state integers `-1024 / 0 / +1024` (3-pos) or `-1024 / +1024` (2-pos). Don't compare to `1` or `true`.
- **Logical switches** (`ls1`...) return `-1024` (off) / `+1024` (on), not 0/1 (`mixer.cpp`, v2.12.4; confirmed in the TX16S MK3 simulator). Test with `> 0` or use `getLogicalSwitchValue(n)`.
- **`getValue` can return a table**, not a number, for GPS sources and the `Cels` multi-cell sensor. Arithmetic on a table crashes: `type()`-check first if you are unsure.

## `touchState` has no `event` field

`touchState.event` is **wrong**: the event is the separate first argument to `refresh`/`run`. The `touchState` table contains only the geometry (`x`, `y`, `startX`/`Y`, `slideX`/`Y`, `swipeUp`/`Down`/`Left`/`Right`, `tapCount`). Old Lua snippets copied from forums sometimes get this wrong; fix them or they will silently no-op on color radios.

## FAI mode hides sensors

When FAI mode (competition rule compliance) is active, every telemetry sensor whose unit is **not volts or dB** is blocked: `getValue` returns `0` and `getSourceValue` returns **no value**, regardless of the real value, while `getFieldInfo` still finds the sensor (block in `getValue`, `mixer.cpp` via `IS_FAI_FORBIDDEN`; allowed units in `isFaiForbidden`, `telemetry/telemetry_sensors.cpp`; `getSourceValue` passes the invalid flag on, `api_general.cpp`; v2.12.4).

- **What stays readable:** sensors in volts (e.g. `RxBt`) and dB (e.g. ELRS `RSNR`). ELRS `1RSS`/`2RSS` are **dBm**, not dB, so they are blocked, as are `RQly` (%) and `RFMD` (raw). `getRSSI()` is not affected, it does not read a sensor (`luaGetRSSI`, `api_general.cpp`).
- **Trap:** a script that treats a blocked sensor as a real 0 misreads it (0 dBm looks like a perfect signal) and fails silently, since the sensor exists and the link is up.
- **When it can be active:** FAI is a firmware build option, off by default (`option(FAI ... OFF)`, `radio/src/CMakeLists.txt`). The build tools offer it for most radios, color radios included (TX16S, T16, T18, X10, X12S), as `faimode` (`FAI=YES`, always on) and `faichoice` (`FAI=CHOICE`, a radio setting stored as `fai` in `radio.yml`) (`radio/util/fwoptions.py`, v2.12.4). The radio setup screen offers the `faichoice` toggle only on B/W radios (`gui/128x64`, `gui/212x64`); the color UI has none (`gui/colorlcd`), so there it can only be set outside the radio UI (`radio.yml`, likely also Companion). The firmware's "options" list names it (`FAImode` / `FAIchoice`, `options.h`). A standard download without these options never has FAI active.
- The OpenTX build-option docs describe `faimode` as "disables all telemetry except for RSSI and voltage", which matches the unit rule above: the FrSky `RSSI` sensor is in dB. With ELRS, "RSSI" means `1RSS`/`2RSS` in dBm and is therefore **not** kept ([OpenTX 2.2 manual, Build Options](https://doc.open-tx.org/manual-for-opentx-2-2/radio_options)). The EdgeTX Lua reference only says "non allowed sensors" (`getValue`, `getSourceValue`).
- Verified identical in v2.11.0 and v2.12.4.
- `getGeneralSettings()` has **no FAI field**. A sensor that exists (`getFieldInfo`) but yields no value from `getSourceValue` is either blocked by FAI or has never been received.

## Lua language subset

What EdgeTX provides (`thirdparty/Lua/src/lua.h`, `luaconf.h`, `linit.c`, v2.12.4; confirmed in the TX16S MK3 simulator: `_VERSION`, `coroutine == nil`, `5 & 3`, `math.maxinteger == 2147483647`):
- **Lua 5.3.6**: native bitwise operators (`&`, `|`, `~`, `<<`, `>>`) and integer division `//`; `bit32` exists as well
- **Real integers and floats, 32 bit each** (`LUA_32BITS`; `math.type(1)` is `"integer"`; confirmed in the TX16S MK3 simulator): integers overflow past ~2.1e9, floats have ~7 significant digits. GPS degrees resolve to roughly 0.4 m at 48° latitude, and distance maths on nearby points loses precision accordingly
- `string`, `math`; `table` on color radios only
- A *restricted* `io` (see api-reference)

**No method syntax on strings.** The `string` library exists, but it is **not bound as a metatable on string values** on EdgeTX. So `s:lower()`, `s:match(...)`, `s:sub(...)`: any `string:method()` call; fails on real firmware (and in the simulator). Always use the free functions: `string.lower(s)`, `string.match(s, ...)`, `string.sub(s, ...)`. This affects *all* string methods, not a specific subset, because the metatable binding itself is missing: it is build-wide, not version-specific (`linit.c` only binds it under `LUA_ENABLE_STRLIB_MT`, which is never defined, v2.12.4; confirmed in the TX16S MK3 simulator). (Same reason file handles reject `f:read(...)`; see api-reference.md.)

> **Test-harness blind spot:** a host Lua interpreter (e.g. the Lua 5.5 test harness) *does* install the string metatable, so `fname:lower():match("%.wav$")` passes in tests and then throws on the device: a classic "runs in the test, breaks on the hardware" trap. Often the throw is swallowed silently inside a `pcall`. Write `string.match(string.lower(fname), "%.wav$")` instead.

**Floats where integers are expected are silently floored, on the radio only.** EdgeTX builds Lua with `LUA_FLOORN2I 1` (`thirdparty/Lua/src/luaconf.h`, v2.12.4; confirmed in the TX16S MK3 simulator) so API functions accept unrounded floats: `string.format("%d", 3.7)` gives `"3"`, `-0.5` gives `"-1"`, and `lcd.drawText(10.6, ...)` draws at x = 10. Equality is not affected (`3.5 == 3` stays false). Desktop Lua (5.3 up to 5.5) instead **throws** `number has no integer representation` for the same `%d` call. Sensor values with decimals (`Alt`, `RxBt`, `VSpd`) are floats, so round explicitly where it matters and to keep host tests and radio in step: `string.format("%d", math.floor(v + 0.5))`, or use `%.0f` / `%.1f`.

What is **NOT** available: do not even try:
- `os`: no `os.time`, `os.date`, `os.execute`, `os.getenv`
- `require`: use `loadScript` instead
- `package`, `module`
- `debug`
- `io.popen`, `io.lines`
- Coroutines (`coroutine`): the library is not loaded
- `print()` output: visible only in the simulator's log; in normal radio firmware it goes nowhere (see `debugging.md`)

## Performance limits

- **The CPU budget depends on the script type** (v2.12.4), it is not a "30 ms watchdog":

  | Script type | Limit | When exceeded |
  | --- | --- | --- |
  | Widget (`lua/widgets.cpp`, `lua_widget.cpp`) | **20,000 Lua VM instructions per call** of `create`/`refresh`/`update`/`background` | error **"CPU limit"**, the widget shows the error instead of its content (confirmed in the TX16S MK3 simulator) |
  | Mix / function scripts (`lua/interface.cpp`) | **50 ms** run time per cycle | no error: the script is paused and resumed next cycle, so its output lags |
  | Tools (`gui/colorlcd/standalone_lua.cpp`) | **none** | a long loop just freezes the screen until it finishes (confirmed in the TX16S MK3 simulator) |

  Heavy work must be split across calls either way. `getUsage()` returns how much of the instruction budget the current call has used (0..100 %).
- **No `sleep`**. There is no `sleep` function. A busy-wait loop hits the limits above ("CPU limit" in a widget, a frozen screen in a tool). To wait, store the start time with `getTime()` and check elapsed ticks each frame.
- **Memory:** on TX16S, TX15 and TX16S MK3 Lua may use up to **6 MB**, of which at most **2 MB for bitmaps**; beyond that `Bitmap.open` returns an empty bitmap (`boards/rm-h750/board.h`, `targets/horus/board.h`, v2.12.4). The old "tens of KB" is B/W-radio lore. Still avoid, mainly because it costs instructions from the CPU budget above and garbage-collection time:
  - Allocating tables inside `run`/`refresh` (reuse one outer table)
  - String concatenation in loops (`table.concat` is cheaper)
  - Opening bitmaps per frame (load once, cache; they also count against the 2 MB)
- **Garbage collection** runs automatically but you can call `collectgarbage("collect")` once after a heavy init to reclaim memory immediately.

## Drawing pitfalls

- **Forgetting `lcd.clear()`** in telemetry/tool `run`: the previous frame remains visible underneath new draws. Always clear first.
- **Drawing outside the widget zone:** widgets draw in **zone-local** coordinates: `(0,0)` is the top-left of the zone and `zone.x`/`zone.y` are always `0`. Stay inside `0..zone.w` and `0..zone.h`: anything beyond is clipped away by EdgeTX (`lua_widget.cpp`, v2.12.4), so it simply doesn't show. The old "add `zone.x`/`zone.y`" rule from OpenTX docs is a harmless no-op on modern EdgeTX, not a requirement. (Telemetry/fullscreen scripts and tools own the whole screen, where `(0,0)` is the screen corner.) (confirmed in the TX16S MK3 simulator)
- **Hard-coded coordinates** break on radios with a different `LCD_W`/`LCD_H` (480×272, 480×320, 800×480). Compute everything from `LCD_W`/`LCD_H` or `zone.w`/`zone.h`.
- **Old color constants** (`BLACK`, `WHITE`, `RED`...) still work but ignore the user's theme. Prefer `COLOR_THEME_*`.
- **`PREC1`/`PREC2`** on `drawNumber`: pass the raw integer multiplied by 10 or 100; `drawNumber(x, y, 235, PREC1)` renders as `23.5`. Forgetting this prints the wrong value.
- **`BOLD` + a size flag gives the next size, not bold text (color radios).** The font is a 4-bit *index* in the flags (`FONT_MASK 0x0F00`, `fonts.h`), not a set of attributes, so adding flags adds indices. `BOLD` is index 1:

  | Constant | Value | Index | + `BOLD` gives | Height 480×272 (px) | Height 800×480 (px) |
  | --- | --- | --- | --- | --- | --- |
  | (none) | `0x000` | 0 | `BOLD` (real bold) | 21 | 27 → 27 |
  | `BOLD` | `0x100` | 1 | | | 27 |
  | `TINSIZE` | `0x200` | 2 | `SMLSIZE` | 12 | 17 → 23 |
  | `SMLSIZE` | `0x300` | 3 | `MIDSIZE` | 17 | 23 → 42 |
  | `MIDSIZE` | `0x400` | 4 | `DBLSIZE` | 29 | 42 → 55 |
  | `DBLSIZE` | `0x500` | 5 | `XXLSIZE` | 40 | 55 → 93 |
  | `XXLSIZE` | `0x600` | 6 | `XLSIZE` (**smaller**) | 69 | 93 → 71 |
  | `XLSIZE` | `0x700` | 7 | index 8: no font, don't | | 71 |

  The same trap hits **`VBOTTOM`** (`0x200`, also inside the font bits): `SMLSIZE + VBOTTOM` renders as `DBLSIZE`, and without a size flag the text becomes `TINSIZE` (`libopenui_defines.h`, v2.12.4; confirmed in the TX16S MK3 simulator). Don't use `VBOTTOM`; compute the y position from `lcd.sizeText` instead.

  Bold exists only at standard size (`BOLD` alone). `DBLSIZE`, `XXLSIZE` and `XLSIZE` are bold by design, `MIDSIZE` and smaller are regular. Never combine `BOLD` with a size: a layout measured with the plain font then overflows. (Verified: EdgeTX 2.12.4 source `fonts.h`/`api_general.cpp`, heights of "Ag" from `lcd.sizeText` in the TX16S (480×272) and TX16S MK3 (800×480) simulator profiles.)
- **Only some non-ASCII characters render (color radios), and `±` breaks the large fonts.** Lua strings are drawn as UTF-8; the built-in fonts carry ASCII plus a few extra ranges, which differ per font (glyph ranges in `fonts/lvgl/make_fonts.sh`, flag-to-font table in `gui/colorlcd/fonts.cpp`, v2.12.4; default English font set, other UI languages add their own glyphs). Every cell below is confirmed in the TX16S MK3 simulator with a glyph test widget (each character between two `|`), except `² µ ·` in `XLSIZE`: that line shared a page with `±`, which crashed it.

  | Glyphs | `TINSIZE`, `SMLSIZE`, standard, `BOLD` | `MIDSIZE`, `DBLSIZE` | `XXLSIZE`, `XLSIZE` |
  | --- | :---: | :---: | :---: |
  | ASCII `0x20-0x7F` | yes | yes | yes |
  | Degree sign `°` (U+00B0) | yes | yes | yes |
  | Accented Latin letters (U+00C0-U+017F: `ä ö ü ß é ñ` ...) | yes | yes | dropped |
  | Bullet `•` (U+2022), `≥` (U+2265) | yes | dropped | dropped |
  | Dashes, curly quotes, ellipsis (`— “ …`), `² µ ·` | dropped | dropped | dropped |
  | **Plus-minus `±` (U+00B1)** | drawn as `À` | drawn as `À` | **garbage block or crash** |

  - **Dropped** means the character vanishes with zero width, no gap and no fallback box: `"|—|"` draws as `"||"`, so `"change — no data"` shows as `"change  no data"`. Besides the table this applies to the non-breaking space and the rest of U+00A0-U+00BF (`²`, `µ`, `·`, `©` ...).
  - **`±` is worse than missing:** it is drawn with the glyph that follows `°` in the font. In the smaller fonts that is `À`; `XXLSIZE` and `XLSIZE` have no glyph after `°`, so EdgeTX renders unrelated memory as a glyph: a block of pixel garbage about 500 px wide (drawn over text above it too), or the simulator crashes and keeps crashing on every start while the widget still draws it. Why only U+00B1 is hit is not confirmed in the source (likely the font's character map runs one entry past `°`); `²`, `µ` and `·` right behind it are dropped normally. Never draw `±`, write `+/-`. Assume the radio behaves the same (same font data), not tested there.
  - The degree sign works in every font, written straight in the source or as its UTF-8 bytes `"\194\176"`.
  - Keep dashes, quotes and placeholders ASCII (`-`, `"`, `'`, `...`, `"-"` not `"—"`). Editors often auto-"smarten" `--` into `—` on paste: check the literal.

## API and value pitfalls

- **`getValue("XYZ")` returning 0** usually means the name is wrong (case-sensitive on telemetry sensors) or telemetry is not yet received. Always handle the 0 case explicitly. (case sensitivity confirmed in the TX16S MK3 simulator)
- **0 is often a valid value, so `getValue` can't tell "missing" from "zero".** Prefer `getSourceValue` (returns no value when missing, plus `isCurrent`/`isFresh`, see api-reference). With `getValue`: ELRS `RFMD` 0 is a real mode, `VSpd` 0 is hover, `Curr` 0 is motor off. Test existence with `getFieldInfo`, which returns **no value** for an unknown source (`api_general.cpp`, v2.12.4). That acts as `nil` in comparisons and `if`, but not when passed straight on as an argument (wrap it: `(getFieldInfo(n))`, see `fstat` in api-reference):
  ```lua
  local function sensorExists(name) return getFieldInfo(name) ~= nil end
  ```
  A sensor appears only after telemetry discovery, so it can show up after the script started: re-check periodically (e.g. once per second) instead of once at load, and cache the result between checks rather than calling it every frame. Ready-made: `patterns.md` → Sensor existence (throttled).
- **Switch values are tri-state integers**: `-1024 / 0 / +1024` for SA/SB/SC (3-position), `-1024 / +1024` for 2-position. Don't compare to `1` or `true`.
- **Logical switches** (`ls1`...) return `-1024` (off) / `+1024` (on), not 0/1 (`mixer.cpp`, v2.12.4; confirmed in the TX16S MK3 simulator). Test with `> 0` or use `getLogicalSwitchValue(n)`.
- **Sensor names with `+` / `-` suffixes** (`Alt+`, `Cels-`) give max/min recorded values; the bare name gives the live value.
- **`model.set*` is saved with a delay**: EdgeTX writes the model a few seconds after the last change (see api-reference → Saving). Powering off right after a change can lose it; don't call setters every frame.
- **`Bitmap.open` failing** (missing/broken file, low memory, or the 2 MB bitmap limit reached) returns a bitmap of **size 0** that draws nothing: no placeholder, no warning (`api_colorlcd.cpp`, v2.12.4; confirmed in the TX16S MK3 simulator). Check after loading: `local w = Bitmap.getSize(bmp); if w == 0 then --[[ failed ]] end`.

## Widget lifecycle pitfalls

- **`update(widget, options)`** is called when the user changes options in the configuration dialog, and also when the zone changes size/position or the widget enters fullscreen (see `script-types.md` → Widget). If you cache option- or size-derived state in `create`, you must recompute it in `update`: otherwise the widget keeps using stale settings or a stale layout.
- **`background(widget)`** runs even when the widget is not visible. Do *not* call any `lcd.*` function here: it will crash or be ignored, version-dependent.
- **`background()` does *not* run while the widget is visible.** Each cycle EdgeTX calls **either** `refresh()` (widget on screen or fullscreen) **or** `background()` (otherwise), never both (`WidgetsContainer::refreshWidgets`, v2.12.4). Logic placed only in `background()` freezes exactly while the pilot looks at the widget, and never runs in fullscreen. Drive the logic from both, throttled so it runs at a fixed rate whoever calls it: (confirmed in the TX16S MK3 simulator)
  ```lua
  local TICK = 10  -- getTime() units (10 ms): 0.1 s
  local function tick(w)
    local now = getTime()
    if now - (w.lastTick or 0) < TICK then return end
    w.lastTick = now
    -- read sensors, evaluate, play alerts (no lcd.*)
  end
  local function background(w) tick(w) end
  local function refresh(w, event, touchState) tick(w); --[[ then draw ]] end
  ```
- **Multiple widget instances** can share the same script. Per-instance state belongs in the table returned by `create`, **never** in script-level locals.

## Tool / script halt causes

If EdgeTX shows "Script halted" or your script just stops:
1. Exceeded per-frame time budget repeatedly
2. Uncaught Lua error (nil indexing is the most common)
3. Out of memory after repeated allocations
4. Wrong return table: missing required function for the script type
5. Old API call removed in your EdgeTX version (check release notes if updating)

Wrap risky code with `pcall`:
```lua
local ok, err = pcall(function() ... end)
if not ok then
  lcd.drawText(0, 0, tostring(err), SMLSIZE + COLOR_THEME_WARNING)
end
```

## File / SD card pitfalls

- **Case in paths:** on the radio FatFs keeps the spelling but matches case-insensitively (`thirdparty/FatFs/ffconf.h`, v2.12.4), so `/scripts/x.lua` finds `/SCRIPTS/X.lua`. A simulator uses the host file system, which is case-sensitive on Linux. Write paths exactly as they are named on the card.
- Writes to the SD card **block** the radio's UI for the duration of the write. Avoid frequent writes: buffer in RAM and flush on exit or every few seconds at most.
- The SD card is unmounted briefly during firmware updates; don't keep file handles across reboots (you can't anyway, but it bears stating).

## OpenTX → EdgeTX worth knowing

Even though the user does not want a migration guide, these gotchas trip up code copied from old OpenTX scripts:

- `EVT_ENTER_BREAK`, `EVT_EXIT_BREAK`, etc. → replaced by `EVT_VIRTUAL_*` constants
- Color constants reorganized: prefer `COLOR_THEME_*`; the old fixed-color names work but mix poorly with themes
- Widget drawing is **zone-local** on EdgeTX: `(0,0)` is the zone corner. Old OpenTX code that adds `zone.x`/`zone.y` is harmless (they are 0) but unnecessary; see `script-types.md` → Widget
