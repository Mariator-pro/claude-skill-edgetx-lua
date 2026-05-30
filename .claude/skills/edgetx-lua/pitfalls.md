# Common Pitfalls & Constraints

EdgeTX Lua is **not** standard Lua 5.x — it is a stripped-down sandbox running on a microcontroller. Most "weird" bugs come from violating one of the constraints below. Limits below are verified against the official EdgeTX 2.10 Lua reference at <https://luadoc.edgetx.org/>.

## Silent script load failures

These will make your script seem to "not exist" without any error:

- **Telemetry / Mix / Function script filename > 6 chars** (without `.lua`). EdgeTX silently skips files with longer base names. `telemetry.lua` → reject. `mytlm.lua` → ok.
- **Widget `name` field > 10 chars**. The widget will not appear in the picker.
- **Widget option name > 10 chars or contains a space**. Whole `options` array is rejected → widget loads but is unconfigurable.
- **More than 5 widget options** on EdgeTX 2.10 (10 on 2.11+). Extra options are silently dropped.
- **Mix script with more than 6 inputs** or with `VALUE` name > 8 chars — input is rejected.
- **Mix script output name > 4 chars** (5 if it starts with `+`/`-`) — the output is rejected / silently truncated.

## Wrong value ranges

- Mix-script **`VALUE` inputs are restricted to -128..+127**, not the ±1024 channel range. Default outside that range is also rejected. `SOURCE` inputs *do* deliver ±1024.
- **`BOOL` widget options are 0 or 1**, not Lua booleans. `if widget.options.MyBool then` works, but `if widget.options.MyBool == true then` always fails.
- **Switch sources** return tri-state integers `-1024 / 0 / +1024` (3-pos) or `-1024 / +1024` (2-pos). Don't compare to `1` or `true`.
- **Logical switches** (`ls1`...) return `0` or `1` — these *are* boolean-ish.
- **`getValue` can return a table**, not a number, for GPS sources and the `Cels` multi-cell sensor. Arithmetic on a table crashes — `type()`-check first if you are unsure.

## `touchState` has no `event` field

`touchState.event` is **wrong** — the event is the separate first argument to `refresh`/`run`. The `touchState` table contains only the geometry (`x`, `y`, `startX`/`Y`, `slideX`/`Y`, `swipeUp`/`Down`/`Left`/`Right`, `tapCount`). Old Lua snippets copied from forums sometimes get this wrong; fix them or they will silently no-op on color radios.

## FAI mode hides sensors

When the user enables FAI mode (competition rule compliance), many telemetry sensors return `0` from `getValue` regardless of the real value. If your script must work under FAI, check `getGeneralSettings()` or accept that the user may have to disable FAI.

## Lua language subset

What EdgeTX provides:
- Lua 5.2-ish syntax
- Standard `table`, `string`, `math` libraries
- A *restricted* `io` (see api-reference)
- `bit32` (or `bit` on older builds) for bitwise ops

What is **NOT** available — do not even try:
- `os` — no `os.time`, `os.date`, `os.execute`, `os.getenv`
- `require` — use `loadScript` instead
- `package`, `module`
- `debug`
- `io.popen`, `io.lines`
- Coroutines (`coroutine`) — *may* be present in some builds but unreliable; avoid
- `print()` outputs to the EdgeTX console (only visible in the simulator / on `dmesg`-like log) — it does **not** appear on the radio screen
- Floats: Lua numbers are floats internally on EdgeTX, but you cannot rely on full double precision; treat values as ~32-bit float

## Performance limits

- **Per-frame budget ≈ 30 ms** on color radios. The watchdog will *halt your script* if you exceed it repeatedly (the screen freezes and EdgeTX shows "Script Error" or silently disables the script). Heavy work must be split across frames.
- **No `sleep`**. There is no `sleep` function — if you write one with a busy loop, the watchdog kills you. To wait, store the start time with `getTime()` and check elapsed ticks each frame.
- **Memory is tight.** Each Lua context has ~tens of KB free. Avoid:
  - Allocating tables inside `run`/`refresh` (reuse one outer table)
  - String concatenation in loops (`table.concat` is cheaper)
  - Opening bitmaps per frame
- **Garbage collection** runs automatically but you can call `collectgarbage("collect")` once after a heavy init to reclaim memory immediately.

## Drawing pitfalls

- **Forgetting `lcd.clear()`** in telemetry/tool `run`: the previous frame remains visible underneath new draws. Always clear first.
- **Drawing outside the widget zone:** writes outside the zone collide with other widgets or the status bar — they may be clipped or not, depending on EdgeTX version. Stay strictly inside `zone.x..zone.x+zone.w` and `zone.y..zone.y+zone.h`.
- **Hard-coded coordinates** break on radios with a different `LCD_W`/`LCD_H` (Pocket is portrait!). Compute everything from `LCD_W`/`LCD_H` or `zone.w`/`zone.h`.
- **Old color constants** (`BLACK`, `WHITE`, `RED`...) still work but ignore the user's theme. Prefer `COLOR_THEME_*`.
- **`PREC1`/`PREC2`** on `drawNumber`: pass the raw integer multiplied by 10 or 100 — `drawNumber(x, y, 235, PREC1)` renders as `23.5`. Forgetting this prints the wrong value.

## API and value pitfalls

- **`getValue("XYZ")` returning 0** usually means the name is wrong (case-sensitive on telemetry sensors) or telemetry is not yet received. Always handle the 0 case explicitly.
- **Switch values are tri-state integers**: `-1024 / 0 / +1024` for SA/SB/SC (3-position), `-1024 / +1024` for 2-position. Don't compare to `1` or `true`.
- **Logical switches** (`ls1`...) return `0` or `1` — these *are* boolean-ish.
- **Sensor names with `+` / `-` suffixes** (`Alt+`, `Cels-`) give max/min recorded values; the bare name gives the live value.
- **`model.set*` setters do not always persist** until EdgeTX writes the model file. Don't tear out a section of model setup, fail to commit, and assume it's saved.
- **`Bitmap.open` on a missing file** returns a placeholder and prints a warning — your widget will silently show a tiny "X". Verify file paths.

## Widget lifecycle pitfalls

- **`update(widget, options)`** is called when the user changes options in the configuration dialog. If you cache option-derived state in `create`, you must recompute it in `update` — otherwise the widget keeps using stale settings until next reload.
- **`background(widget)`** runs even when the widget is not visible. Do *not* call any `lcd.*` function here — it will crash or be ignored, version-dependent.
- **Multiple widget instances** can share the same script. Per-instance state belongs in the table returned by `create`, **never** in script-level locals.

## Tool / script halt causes

If EdgeTX shows "Script halted" or your script just stops:
1. Exceeded per-frame time budget repeatedly
2. Uncaught Lua error (nil indexing is the most common)
3. Out of memory after repeated allocations
4. Wrong return table — missing required function for the script type
5. Old API call removed in your EdgeTX version (check release notes if updating)

Wrap risky code with `pcall`:
```lua
local ok, err = pcall(function() ... end)
if not ok then
  lcd.drawText(0, 0, tostring(err), SMLSIZE + COLOR_THEME_WARNING)
end
```

## File / SD card pitfalls

- Path is case-sensitive on the radio's FAT driver in some configurations. Use uppercase folder names (`SCRIPTS`, `WIDGETS`, `SOUNDS`) consistently.
- Writes to the SD card **block** the radio's UI for the duration of the write. Avoid frequent writes — buffer in RAM and flush on exit or every few seconds at most.
- The SD card is unmounted briefly during firmware updates; don't keep file handles across reboots (you can't anyway, but it bears stating).

## OpenTX → EdgeTX worth knowing

Even though the user does not want a migration guide, these gotchas trip up code copied from old OpenTX scripts:

- `EVT_ENTER_BREAK`, `EVT_EXIT_BREAK`, etc. → replaced by `EVT_VIRTUAL_*` constants
- `getGeneralSettings()` → still works; some fields renamed (`imperial` → `imperial`, but watch unit IDs)
- Widget API gained `update` and the `options` array (OpenTX used a different structure)
- Many `model.set*` setters that silently succeeded on OpenTX now validate inputs and may error
- Color constants reorganized: prefer `COLOR_THEME_*`; the old fixed-color names work but mix poorly with themes
