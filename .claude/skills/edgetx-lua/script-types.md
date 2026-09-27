# EdgeTX Script Types

Every EdgeTX Lua file is one of five script types. The script type determines:
- The folder on the SD card where the file must live
- Which functions the file must expose (via the final `return { ... }` table)
- When and how often EdgeTX calls those functions
- What is allowed inside them (LCD access, blocking work, etc.)

Pick the type from the user's intent, then read only that section.

---

## 1. Widget

A widget renders inside a zone on the Main View or Telemetry Screen. Multiple widgets can run simultaneously. Color radios only.

**Path on SD card:**
```
/WIDGETS/<WidgetName>/main.lua
```
Optional companion file: `/WIDGETS/<WidgetName>/icon.png` (for the widget picker).

> The **widget folder name** (`<WidgetName>`) must be **≤ 13 characters**. EdgeTX
> builds `/WIDGETS/<folder>/main.lua` in a 32-byte buffer and silently skips any
> folder whose path doesn't fit, so the widget just never appears in the picker
> (`lua/widgets.cpp`, v2.11.0 and v2.12.4; confirmed in the TX16S MK3 simulator: 13 loads, 14 is skipped). This is separate from the `name` field below.

**Required return table:**
```lua
return {
  name    = "MyWidget",      -- REQUIRED, keep ≤ 20 characters (see limits below)
  create  = create,          -- REQUIRED (zone, options, path) -> widget table
  refresh = refresh,         -- REQUIRED (widget, event, touchState) -> nil
  options = options,         -- OPTIONAL: array of user-configurable options
  update  = update,          -- OPTIONAL (widget, options) -> nil [called when options change]
  background = background,   -- OPTIONAL (widget) -> nil [called when off-screen]
}
```

> EdgeTX registers a widget as soon as `name` and `create` are present (`lua/widgets.cpp`, v2.12.4). If either is missing or misspelled, the widget **silently never appears in the picker**. `refresh` is needed to draw anything; `options`, `update`, `background`, `translate` are optional (`update` is almost always wanted if you have options).

**Widget option limits:**

| Limit                    | EdgeTX 2.10 (docs, not checked in source) | EdgeTX 2.11 (source v2.11.0) | EdgeTX 2.12 (source v2.12.4) |
| ------------------------ | :---------: | :---------: | :---------: |
| Widget `name`            | ≤ 10 chars  | **≤ 20 chars** (stored in a 20-char field; longer is cut, widget likely not found after reload) | **no limit** (stored as string) |
| Option name              | ≤ 10 chars, no spaces | **no length or space check** | same as 2.11 |
| Max number of options    | **5**       | **10**      | **50**      |
| `STRING` option length   | **8 chars** | **12 chars** | **255 chars** |

Options beyond the maximum are silently dropped. Values are stored **by position** in the `options` array, not by name, so reordering options scrambles saved settings.

The option name is only used as the settings-dialog label and as the key in the `options` table the script receives (`options.Transparency`). Spaces work but force `options["My Option"]`, so keep names space-free by convention. (confirmed in the TX16S MK3 simulator)

**`translate(name, lang)`** (optional, 2.11+): if the widget's return table has a `translate` function, EdgeTX calls it for the widget name and for every option name and shows the returned string instead. `lang` is the radio's UI language as two uppercase letters (`"EN"`, `"DE"`). This keeps code keys short while the dialog shows readable labels: (confirmed in the TX16S MK3 simulator)
```lua
local LABELS = { ModLipo = "LiPo module", ModLink = "Link module" }
local function translate(name, lang) return LABELS[name] or name end
return { name = "Wingman", options = options, create = create,
         refresh = refresh, translate = translate }
```

**`options`** is an array of `{ "Name", TYPE, default [, min, max] }` tuples:
- `SOURCE`: any source the user can pick (stick, switch, sensor)
- `VALUE`: number; with optional `min, max` (in addition to `default`)
- `BOOL`: toggles between **0 and 1** (not a Lua `true`/`false`!); test with `== 1`, since 0 is truthy in Lua. The default must be a number (`0`/`1`); a Lua `true` errors on load
- `STRING`: text input, see length limit above
- `COLOR`: color value; default with a `COLOR_THEME_*` constant
- `TIMER`: pick one of the model timers
- `SWITCH`: pick a switch
- `TEXT_SIZE`: pick a font size (small … XXL)
- `ALIGNMENT`: pick left / center / right
- `SLIDER`: numeric value via a slider (EdgeTX 2.11+)
- `CHOICE`: pick from your own list (2.11+): `{ "Mode", CHOICE, 1, { "Off", "Small", "Large" } }`. The value is **1-based**: first entry = 1 (default too; confirmed in the TX16S MK3 simulator: "Second" = 2)
- `FILE`: pick a file (2.11+): `{ "Image", FILE, "logo.png", "/IMAGES/mywidget" }`, the 4th field is the folder to pick from. File name up to 255 chars on 2.12, 12 on 2.11

  (`lua_widget_factory.cpp`, `widget_settings.cpp`, v2.12.4; types present in v2.11.0 as well)

Example:
```lua
local options = {
  { "Source", SOURCE, 0 },
  { "Color",  COLOR,  COLOR_THEME_PRIMARY1 },
  { "Min",    VALUE,  0,   -1024, 1024 },
  { "Max",    VALUE,  100, -1024, 1024 },
}
```

**`create(zone, options, path)`** returns the widget's per-instance state table (`lua_widget.cpp`, `lua_widget_factory.cpp`, v2.12.4):
- `zone` holds `x = 0`, `y = 0` (always 0), `w`, `h` (size) plus `xabs`, `yabs` (absolute screen position of the zone). Use `zone.w`/`zone.h` for sizing; **stay within `0..zone.w` / `0..zone.h`** (see coordinate note below). EdgeTX updates this same table **in place** when the zone changes, so keeping `ctx.zone = zone` always sees the current size.
- `options` see above (read-only for the script).
- `path` is the widget's folder with a trailing slash, e.g. `"/WIDGETS/MyWidget/"`, handy for loading files next to `main.lua`.

**`update(widget, options)`** is called not only after the settings dialog, but also when the zone's size or position changes and when the widget enters fullscreen (`widget.cpp`, `lua_widget.cpp`, v2.12.4; confirmed in the TX16S MK3 simulator: called right after start without any dialog). Recompute size-dependent layout there.

> **Coordinate origin: a widget draws in ZONE-LOCAL coordinates.**
> `(0, 0)` is the **top-left of the widget's zone**, and `zone.x`/`zone.y` are
> always `0` (set to 0 in `lua_widget_factory.cpp`, v2.12.4). Draw within `0..zone.w` / `0..zone.h`, e.g.
> `lcd.drawFilledRectangle(0, 0, zone.w, zone.h, …)`.
> Legacy OpenTX docs (still echoed by luadoc.edgetx.org / `llms-full.txt`) say to
> add `zone.x`/`zone.y`; on modern EdgeTX that is a harmless no-op but
> unnecessary.
> Note: this is **widget-specific**. Telemetry/fullscreen scripts and tools own
> the whole screen, where `(0,0)` is the screen corner.

**`refresh(widget, event, touchState)`** is called on every redraw (typically every ~50 ms / 20 Hz on color radios when the widget is visible).
- `event` is `nil` when the widget is not in fullscreen mode; `0` or a key/touch event constant when fullscreen. (confirmed in the TX16S MK3 simulator)
- `touchState` is a table on touch radios when the current event is a touch event; otherwise `nil`.
- Draw in zone-local coordinates: `lcd.drawText(dx, dy, ...)` with `dx`/`dy` in `0..zone.w` / `0..zone.h`. (`zone.x`/`zone.y` are `0` on modern EdgeTX; see the coordinate note above.)
- `lcd.clear()` is NOT required in widget `refresh`: EdgeTX paints the theme background for you.

**`background(widget)`** runs when the widget is *not* visible but still loaded. Use it to keep state warm (timers, logging) but do **not** call `lcd.*` here.

---

## 2. Telemetry / Fullscreen Script (B/W radios only)

> **Not available on color radios** (TX16S, TX15, Boxer, …). Loading of `/SCRIPTS/TELEMETRY/` is compiled only for the B/W Taranis family (`PCBTARANIS` in `lua/interface.cpp`, v2.12.4); color radios have no such script type and no menu entry for it. For a fullscreen page on a color radio use a **widget** on a one-zone layout or in widget fullscreen mode (section 1).

A fullscreen page added to the model's telemetry screens. Activated by scrolling through telemetry pages on the radio.

**Path on SD card:**
```
/SCRIPTS/TELEMETRY/<name>.lua
```
**File name (without `.lua`) must be ≤ 6 characters**: EdgeTX silently ignores longer names.

Then assigned in Model Setup → Display → Add → Script.

**Required return table:**
```lua
return {
  run        = run,        -- REQUIRED   (event) -> nil
  init       = init,       -- OPTIONAL   () -> nil   [called once when loaded]
  background = background, -- OPTIONAL   () -> nil   [called when off-screen]
}
```

**`run(event)`** owns the full screen: call `lcd.clear()` first, then draw. Called every ~50 ms while the page is the active telemetry page.

- `event` is the key event code (e.g. `EVT_VIRTUAL_ENTER`, `EVT_VIRTUAL_EXIT`) or `0` if no key pressed this frame.
- B/W radios have no touch, so `run` only gets `event`.
- Returning a non-zero value from `run` exits the script.

`background()` keeps running while another telemetry page is shown: no `lcd.*` here.

---

## 3. Mix Script (Custom Mixer)

Runs as a mixer source. Used to compute custom outputs that feed into the model's mix table.

**Path on SD card:**
```
/SCRIPTS/MIXES/<name>.lua
```
**File name (without `.lua`) must be ≤ 6 characters.**

Assigned via Model Setup → Custom Scripts.

**Required return table:**
```lua
return {
  run    = run,    -- REQUIRED  (input1, input2, ...) -> out1, out2, ...
  init   = init,   -- OPTIONAL  () -> nil
  input  = inputs, -- OPTIONAL  array describing input sources
  output = outputs,-- OPTIONAL  array of output names
}
```

**Input format (two flavours):**

`SOURCE` input: user picks any radio source:
```lua
{ "ThrName", SOURCE }
```

`VALUE` input: fixed numeric range:
```lua
{ "Name", VALUE, min, max, default }
```

**Mix-script input/output limits** (`lua/interface.cpp`, `dataconstants.h`, `datastructs_private.h`; v2.11.0 and v2.12.4):

| Limit                       | Value          |
| --------------------------- | -------------- |
| Max number of inputs        | **6**: further entries are silently ignored |
| Max number of outputs       | **6**: further entries are silently ignored |
| Input name length           | 2.11: cut to **6** chars; 2.12: no limit |
| `VALUE` min/max range       | free 16-bit values; **default -100..+100** if min/max are omitted (the old ±128 is OpenTX) |
| Output name length          | cut to **6 characters** (both versions) |

`outputs` example:
```lua
local outputs = { "Out1", "Out2" }     -- names appear in Companion as LUA1a, LUA1b...
                                       -- names longer than 6 chars are cut
```

**`run(...)`** receives one argument per input (in order) and must return one value per output. It runs in the Lua task about **every 50 ms**, not in the mixer itself; the mixer keeps using the last returned values in between (`main.cpp`, `tasks.cpp`, `lua/interface.cpp`, v2.12.4). So it is unsuitable for fast control loops, and any delay only makes its output later. Still do **no** I/O, no `lcd.*`, and avoid allocations. Returned floats are floored to integers.

**Input value scale:** `SOURCE` inputs are integers in `-1024..+1024` (divide by 10.24 for a percentage). `VALUE` inputs arrive in their own min..max range.

---

## 4. Function Script (Special / Global Function)

A background script triggered by a Special Function (per model) or Global Function (across all models). Runs continuously while its trigger condition is active.

**Path on SD card:**
```
/SCRIPTS/FUNCTIONS/<name>.lua
```
**File name (without `.lua`) must be ≤ 6 characters.**

Assigned via Model Setup → Special Functions → "Lua Script" or Radio Setup → Global Functions.

**Required return table:**
```lua
return {
  run        = run,        -- REQUIRED  () -> nil   [no event, no LCD]
  init       = init,       -- OPTIONAL  () -> nil   [called once at load]
  background = background, -- OPTIONAL  () -> nil   [runs while trigger is OFF]
}
```

**Trigger semantics:** `run` is called while the assigned switch / function trigger is **ON**. `background` is called while it is **OFF**. This is a real semantic difference, not just an optional alternative.

**No LCD access** from any of these functions. Use for: persistent logging, model-state automation, sound playback (`playFile`, `playNumber`, `playHaptic`), telemetry processing.

---

## 5. Tool Script (TOOLS menu / One-Shot)

A standalone application launched manually from the TOOLS menu. Owns the whole screen and keypad while running.

**Path on SD card:**
```
/SCRIPTS/TOOLS/<name>.lua
/SCRIPTS/TOOLS/<name>/main.lua     -- folder variant
```
**No documented filename length restriction** for tool scripts (in contrast to telemetry/mix/function which require ≤ 6 chars). The formal v2.6/2.10 reference still calls these "one-time scripts" and recommends `/SCRIPTS/` generally, but the TOOLS menu lists exactly the files above.

**Folder variant:** a subfolder of `/SCRIPTS/TOOLS/` counts as a tool if it contains `main.lua`. If a `<name>.lua` exists next to a `<name>/` folder, the folder is skipped (no duplicate entry). (confirmed in the TX16S MK3 simulator)

**Menu name (`TNS|...|TNE`):** put the name between the literal markers `TNS|` and `|TNE`, usually as a comment on the first line (confirmed in the TX16S MK3 simulator: pipe form, folder variant; #TNS# form, marker after 1024 bytes, 41-char name and missing marker all fall back to the file name):
```lua
-- TNS|My Tool|TNE
```
How EdgeTX reads it (`readToolName` in `radio/src/lua/interface.cpp`, verified in v2.12.4):
- Reads only the **first 1024 bytes** of the file and searches for the literal byte strings `TNS|` and `|TNE`. Whatever surrounds them (`--`, `local toolName = "..."`) does not matter.
- Name length max **40 chars** on radios with `LCD_W > 350` (TX16S, TX15, …), **16 chars** otherwise.
- Markers missing, in the wrong order or name too long → the menu silently shows the **file name** (without `.lua`; the folder name for the folder variant). The tool still works, so a wrong marker is easy to miss.
- `---- #TNS# "My Tool"` / `#TNE#` (seen in some guides) contains no `TNS|` and therefore does **not** work.

**Required return table:**
```lua
return {
  run  = run,    -- REQUIRED  (event [, touchState]) -> exitCode  [non-zero = exit]
  init = init,   -- OPTIONAL  () -> nil
}
```

`run(event, touchState)` is called every frame until it returns a non-zero value (`gui/colorlcd/standalone_lua.cpp`, v2.12.4):
- **Short RTN/EXIT** only delivers `EVT_VIRTUAL_EXIT` to the script: nothing closes by itself. Handle it and `return 1`. (confirmed in the TX16S MK3 simulator)
- **Long RTN/EXIT** is the system escape: EdgeTX closes the tool without asking the script. (confirmed in the TX16S MK3 simulator)
- On touch radios `touchState` is passed as a second argument for touch events, same as for widgets. (confirmed in the TX16S MK3 simulator)

Tools are the one place where blocking-style flow is okay: you control the loop, but each `run` call must still return promptly.

---

## Lifecycle cheat sheet

| Script type | LCD allowed in `run`/`refresh` | LCD allowed in `background` | Touch events | Key events  |
| ----------- | :---:                          | :---:                       | :---:        | :---:       |
| Widget      | ✓ (within zone)                | ✗                           | fullscreen only | fullscreen only |
| Telemetry (B/W only) | ✓ (fullscreen)      | ✗                           | ✗            | ✓           |
| Mix         | ✗                              | n/a                         | ✗            | ✗           |
| Function    | ✗                              | ✗                           | ✗            | ✗           |
| Tool        | ✓ (fullscreen)                 | n/a                         | ✓            | ✓           |

## Loading other files

EdgeTX does **not** support standard `require`. Use:
```lua
local helper = assert(loadScript("/SCRIPTS/TOOLS/mytool/helper.lua"))()
```
`loadScript` returns a function; call it once to execute the chunk and capture its `return` value. Cache the result; don't reload every frame.

- **Errors don't throw:** like `loadfile`, it returns `nil` plus an error message when the file is missing or broken (`api_general.cpp`, v2.12.4). `assert(...)` above turns that into a script error; for optional files check for `nil` instead and degrade gracefully. (confirmed in the TX16S MK3 simulator)
- **Not available on a desktop Lua.** Host-side tests run plain Lua, where `loadScript` doesn't exist. Guard the call so the same file runs in both, and load files in tests with `loadfile`:
  ```lua
  local chunk = loadScript and loadScript("/SCRIPTS/MYAPP/core.lua")
  local core = chunk and chunk()   -- nil if missing, broken, or on the desktop
  ```
- **Mode argument and `.luac` files:** `loadScript(path, mode)` (`luaLoadScriptFileToState`, `lua/interface.cpp`, v2.12.4):

  | Mode | Loads | Writes a `.luac` |
  | --- | --- | --- |
  | `"bt"` (default on the radio) | text or binary, **whichever is newer; the binary wins at equal timestamps** | yes, when the text is newer or no `.luac` exists |
  | `"T"` (default in the simulator) | text, binary only if there is no text | yes |
  | `"t"` / `"b"` | text only / binary only | `"t"`: yes |
  | add `"x"` (e.g. `"tx"`) | as the letters before | **no** |
  | add `"c"` | text, always recompiled | yes, forced |

  The written `.luac` gets the **timestamp of the `.lua`**, not the time it was written, and FAT resolves only 2 s. So a `.lua` rewritten within the same 2 s after a load, or an older `.lua` copied back from a PC, is shadowed on the radio by the stale `.luac`: `"bt"` keeps loading the old content. The simulator (`"T"`) never shows this.
  - **Code** (`core.lua`, helpers): the default is fine, the `.luac` saves RAM and load time.
  - **Data files the script writes itself** (`config.lua`, logs as `return { ... }`): always load with **`"tx"`**: text only, no `.luac` is written, an existing one is ignored.
    ```lua
    local ok, chunk, err = pcall(loadScript, "/SCRIPTS/MYAPP/config.lua", "tx")
    if not ok or not chunk then --[[ missing or broken: err has the reason ]] end
    ```
