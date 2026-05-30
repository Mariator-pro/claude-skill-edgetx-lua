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

> The **widget folder name** (`<WidgetName>`) must be **≤ 8 characters** — this is
> separate from the `name` field below (≤ 10 chars). A folder name longer than 8
> chars can prevent the widget from loading.

**Required return table:**
```lua
return {
  name    = "MyWidget",      -- REQUIRED, max 10 characters
  create  = create,          -- REQUIRED (zone, options) -> widget table
  refresh = refresh,         -- REQUIRED (widget, event, touchState) -> nil
  options = options,         -- OPTIONAL — array of user-configurable options
  update  = update,          -- OPTIONAL (widget, options) -> nil [called when options change]
  background = background,   -- OPTIONAL (widget) -> nil [called when off-screen]
}
```

> Per the official EdgeTX 2.10 docs: `name`, `create`, `refresh` are required. `options`, `update`, `background` are optional. Older guides sometimes describe `update` as required — it isn't, but you almost always want it if you have options.

**Widget option limits (verified against docs):**

| Limit                    | EdgeTX 2.10 | EdgeTX 2.11+ (incl. 2.12) |
| ------------------------ | :---------: | :-----------------------: |
| Widget `name`            | ≤ 10 chars  | ≤ 10 chars                |
| Option name              | ≤ 10 chars, **no spaces** | same                |
| Max number of options    | **5**       | **10**                    |
| `STRING` option length   | **8 chars** | **12 chars**              |

**`options`** is an array of `{ "Name", TYPE, default [, min, max] }` tuples:
- `SOURCE` — any source the user can pick (stick, switch, sensor)
- `VALUE` — number; with optional `min, max` (in addition to `default`)
- `BOOL` — toggles between **0 and 1** (not a Lua `true`/`false`!)
- `STRING` — text input, see length limit above
- `COLOR` — color value; default with a `COLOR_THEME_*` constant
- `TIMER` — pick one of the model timers
- `SWITCH` — pick a switch
- `TEXT_SIZE` — pick a font size (small … XXL)
- `ALIGNMENT` — pick left / center / right
- `SLIDER` — numeric value via a slider (EdgeTX 2.11+)
- `CHOICE` — numeric value from a custom popup list (EdgeTX 2.11+)
- `FILE` — pick a file from storage; filename ≤ 12 chars (EdgeTX 2.11+)

Example:
```lua
local options = {
  { "Source", SOURCE, 0 },
  { "Color",  COLOR,  COLOR_THEME_PRIMARY1 },
  { "Min",    VALUE,  0,   -1024, 1024 },
  { "Max",    VALUE,  100, -1024, 1024 },
}
```

**`create(zone, options)`** returns the widget's per-instance state table. `zone` has `x`, `y`, `w`, `h` — the rectangle the widget owns. **Never draw outside this rectangle.**

**`refresh(widget, event, touchState)`** is called on every redraw (typically every ~50 ms / 20 Hz on color radios when the widget is visible).
- `event` is `nil` when the widget is not in fullscreen mode; `0` or a key/touch event constant when fullscreen.
- `touchState` is a table on touch radios when the current event is a touch event; otherwise `nil`.
- Use `lcd.drawText(zone.x + dx, zone.y + dy, ...)` — always offset by the zone.
- `lcd.clear()` is NOT required in widget `refresh` — EdgeTX paints the theme background for you.

**`background(widget)`** runs when the widget is *not* visible but still loaded. Use it to keep state warm (timers, logging) but do **not** call `lcd.*` here.

---

## 2. Telemetry / Fullscreen Script

A fullscreen page added to the model's telemetry screens. Activated by scrolling through telemetry pages on the radio.

**Path on SD card:**
```
/SCRIPTS/TELEMETRY/<name>.lua
```
**File name (without `.lua`) must be ≤ 6 characters** — EdgeTX silently ignores longer names.

Then assigned in Model Setup → Display → Add → Script.

**Required return table:**
```lua
return {
  run        = run,        -- REQUIRED   (event [, touchState]) -> nil
  init       = init,       -- OPTIONAL   () -> nil   [called once when loaded]
  background = background, -- OPTIONAL   () -> nil   [called when off-screen]
}
```

**`run(event, touchState)`** owns the full screen — call `lcd.clear()` first, then draw. Called every ~50 ms while the page is the active telemetry page.

- `event` is the key event code (e.g. `EVT_VIRTUAL_ENTER`, `EVT_VIRTUAL_EXIT`) or `0` if no key pressed this frame.
- `touchState` is passed as a second argument on color touch radios when the current event is a touch event; on B/W radios there is only the `event` argument (`run(event)`).
- Returning a non-zero value from `run` exits the script.

`background()` keeps running while another telemetry page is shown — no `lcd.*` here.

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

`SOURCE` input — user picks any radio source:
```lua
{ "ThrName", SOURCE }
```

`VALUE` input — fixed numeric range:
```lua
{ "Name", VALUE, min, max, default }
```

**Mix-script input/output limits (verified):**

| Limit                       | Value          |
| --------------------------- | -------------- |
| Max number of inputs        | **6**          |
| Max number of outputs       | **6**          |
| `VALUE` input name length   | ≤ 8 characters |
| `VALUE` min/max range       | **-128 to +127** (NOT ±1024) |
| Output name length          | **≤ 4 characters** (5 if the first char is `+`/`-`) |

`outputs` example:
```lua
local outputs = { "Out1", "Out2" }     -- names appear in Companion as LUA1a, LUA1b...
                                       -- each output name must be 4 chars or less
```

**`run(...)`** receives one argument per input (in order) and must return one value per output. It is called on every mixer cycle (target ~30 ms) — extremely time-critical. Do **no** I/O, no `lcd.*`, and avoid allocations.

**Input value scale:** `SOURCE` inputs are integers in `-1024..+1024` (divide by 10.24 for a percentage). **The ±128 range applies only to `VALUE` inputs.**

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
```
**No documented filename length restriction** for tool scripts (in contrast to telemetry/mix/function which require ≤ 6 chars). The TOOLS-menu convention with `/SCRIPTS/TOOLS/` and the `#TNS#/#TNE#` markers below is current EdgeTX behaviour, even though the formal v2.6/2.10 reference still calls these "one-time scripts" and recommends `/SCRIPTS/` generally.

EdgeTX scans the `/SCRIPTS/TOOLS/` folder at boot; the first lines of the file should be label markers:
```lua
---- #TNS# "My Tool"
---- #TNE#
```
`#TNS#` (Tool Name Start) and `#TNE#` (Tool Name End) tell EdgeTX what to show in the menu without parsing the whole file. The string between them becomes the menu entry.

**Required return table:**
```lua
return {
  run  = run,    -- REQUIRED  (event) -> exitCode  [non-zero = exit]
  init = init,   -- OPTIONAL  () -> nil
}
```

`run(event)` is called every frame until the user exits with `EVT_VIRTUAL_EXIT` (RTN/Exit key) or you return a non-zero value. Tools are the one place where blocking-style flow is okay — you control the loop, but each `run` call must still return promptly.

---

## Lifecycle cheat sheet

| Script type | LCD allowed in `run`/`refresh` | LCD allowed in `background` | Touch events | Key events  |
| ----------- | :---:                          | :---:                       | :---:        | :---:       |
| Widget      | ✓ (within zone)                | ✗                           | fullscreen only | fullscreen only |
| Telemetry   | ✓ (fullscreen)                 | ✗                           | ✓            | ✓           |
| Mix         | ✗                              | n/a                         | ✗            | ✗           |
| Function    | ✗                              | ✗                           | ✗            | ✗           |
| Tool        | ✓ (fullscreen)                 | n/a                         | ✓            | ✓           |

## Loading other files

EdgeTX does **not** support standard `require`. Use:
```lua
local helper = assert(loadScript("/SCRIPTS/TOOLS/mytool/helper.lua"))()
```
`loadScript` returns a function; call it once to execute the chunk and capture its `return` value. Cache the result; don't reload every frame.
