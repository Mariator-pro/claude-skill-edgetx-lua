# EdgeTX Lua API Reference

Condensed reference of the EdgeTX-specific APIs most often needed when writing scripts. Function signatures and constants are taken from the official EdgeTX Lua Reference Guide at <https://luadoc.edgetx.org/>, which is maintained for **EdgeTX 2.10** as the baseline (with notes about changes in 2.11 and 2.12 where relevant). When in doubt, defer to that guide.

---

## 1. LCD / Drawing API (color radios)

Available wherever LCD calls are allowed (widget `refresh`, telemetry `run`, tool `run`). Coordinates are in pixels with origin `(0, 0)` at top-left.

### Screen / clearing
```lua
lcd.clear([color])           -- fill screen with color (default: theme bg)
LCD_W, LCD_H                 -- globals: full screen width / height in pixels
```

### Text
```lua
lcd.drawText(x, y, text [, flags])
lcd.drawNumber(x, y, value [, flags])      -- integer; PREC1/PREC2 = decimal places
lcd.drawTimer(x, y, seconds [, flags])     -- "MM:SS" style; add TIMEHOUR to include hours
lcd.sizeText(text [, flags]) -> w, h       -- measure before drawing
```

Common `flags` (OR them together):

| Flag                  | Meaning                                  | Notes              |
| --------------------- | ---------------------------------------- | ------------------ |
| `SMLSIZE`             | small font                               |                    |
| `MIDSIZE`             | medium font                              |                    |
| `DBLSIZE`             | double-height font                       |                    |
| `XXLSIZE`             | extra-large font ("jumbo")               |                    |
| `BOLD`                | bold weight                              | color displays only|
| `INVERS`              | swap fg/bg (highlight)                   |                    |
| `BLINK`               | blinking text                            |                    |
| `LEFT`                | left-justify (default)                   |                    |
| `RIGHT`               | right-justify                            |                    |
| `CENTER`              | horizontally center                      | color displays only|
| `VCENTER`             | vertically center on `y`                 | color displays only|
| `SHADOWED`            | drop-shadow                              | color displays only|
| `FORCE`               | force black pixels (B/W)                 | B/W displays       |
| `ERASE`               | force white pixels (B/W)                 | B/W displays       |
| `GREY_DEFAULT`        | grey fill                                | B/W only           |
| `TIMEHOUR`            | include hours in `drawTimer`             | `drawTimer` only   |

Color is passed by OR-ing a color constant into `flags`, or via `lcd.setColor` / explicit color arg on newer EdgeTX:

```lua
lcd.drawText(10, 10, "Hi", SMLSIZE + COLOR_THEME_PRIMARY1)
```

### Theme colors (preferred — adapt to user's theme)
```
COLOR_THEME_PRIMARY1   COLOR_THEME_PRIMARY2   COLOR_THEME_PRIMARY3
COLOR_THEME_SECONDARY1 COLOR_THEME_SECONDARY2 COLOR_THEME_SECONDARY3
COLOR_THEME_FOCUS      COLOR_THEME_EDIT       COLOR_THEME_ACTIVE
COLOR_THEME_WARNING    COLOR_THEME_DISABLED
CUSTOM_COLOR                                  -- writable via lcd.setColor
```

Theme colors are **indexed** — changing one (e.g. with a custom theme) changes it everywhere it is used.

### Legacy fixed colors (immutable; ignore the user's theme)
```
BLACK  WHITE  LIGHTWHITE
RED    DARKRED
GREEN  DARKGREEN  BRIGHTGREEN
BLUE   DARKBLUE
YELLOW ORANGE
GREY   LIGHTGREY  DARKGREY
LIGHTBROWN  DARKBROWN
```

### Custom colors
```lua
local myRed = lcd.RGB(255, 0, 0)
lcd.drawText(0, 0, "Hot", SMLSIZE + myRed)
```

### Shapes
```lua
lcd.drawLine(x1, y1, x2, y2, pattern, flags)
   -- pattern: SOLID or DOTTED (omit / 0 also draws a solid line). Both are documented constants.
lcd.drawRectangle(x, y, w, h, flags [, thickness])
lcd.drawFilledRectangle(x, y, w, h, flags [, opacity])
lcd.drawCircle(x, y, radius, flags)
lcd.drawFilledCircle(x, y, radius, flags)
lcd.drawTriangle(x1, y1, x2, y2, x3, y3, flags)
lcd.drawAnnulus(x, y, rInner, rOuter, startAngle, endAngle, flags)
lcd.drawPie(x, y, radius, startAngle, endAngle, flags)
lcd.drawGauge(x, y, w, h, fill, maxfill [, flags])
   -- Filled progress/level bar from x,y of size w×h.
   -- The filled portion is fill/maxfill of the rectangle (e.g. fill=cellPercent, maxfill=100).
   -- `flags` accepts color constants for the fill color (default color index 0 if omitted).
```

### Bitmaps
```lua
local bmp = Bitmap.open("/IMAGES/logo.png")
lcd.drawBitmap(bmp, x, y [, scale])    -- scale in percent, e.g. 50 = half size
Bitmap.getSize(bmp) -> w, h
```
Cache bitmaps in `init`/`create`; do not call `Bitmap.open` per frame — it's slow and leaks memory.

### Clipping / scissor (newer EdgeTX)
Some EdgeTX versions expose `lcd.setClipping(x, y, w, h)` for restricting draws to a rect. Useful in widgets if you risk overshooting the zone.

---

## 2. Input / Values

### `getValue(source)`
Returns the current value of any radio source. Returns `0` for non-existing sources, unavailable telemetry, **or sensors restricted in FAI mode**.
```lua
local thr = getValue("thr")           -- by name
local sa  = getValue("sa")            -- switch SA position: -1024 / 0 / 1024
local rss = getValue("RSSI")          -- telemetry by sensor name
local id  = getFieldInfo("thr").id
local v   = getValue(id)              -- by numeric id (faster than by name)
```

`getValue` can also return a **table** for these sources:
- `"latitude"`, `"longitude"` / GPS coords → `{ lat=..., lon=..., ["pilot-lat"]=..., ["pilot-lon"]=... }` (positive = N/E)
- GPS date/time → table in the same shape as `getDateTime()`
- `"Cels"` (multi-cell LiPo) → array of per-cell voltages. `"Cels+"` / `"Cels-"` return a single max/min scalar.

Always `type()`-check before doing arithmetic on a sensor result you have not confirmed is a number.

Common source name patterns:
- Sticks: `thr`, `rud`, `ele`, `ail`
- Trims: `trim-thr` etc.
- Pots/Sliders: `s1`, `s2`, `ls`, `rs`
- Switches: `sa`, `sb`, ..., `sh` — return `-1024`/`0`/`+1024` for 3-pos
- Logical Switches: `ls1`...`ls64` — return `0` or `1`
- Trainer / Sim inputs: `tr1`..`tr16`
- Channels: `ch1`..`ch32` — output channel values
- Special: `clock`, `tx-voltage`, `tx-time`, `RSSI`, `RAS`, `RxBt`
- Custom telemetry sensors: by the name set in Model → Telemetry

Value scale conventions:
- Sticks / pots / channels: `-1024` (full negative) to `+1024` (full positive)
- Logical switches: `0` (false) or `1` (true)
- Sensor values: native units (V, A, m/s, m, °, ...) — depends on sensor

### `getFieldInfo(nameOrId)`
```lua
local info = getFieldInfo("thr")
-- info.id, info.name, info.desc, info.unit
```
Use `id` for repeated `getValue` calls in hot paths.

### `getRSSI()` → number, number
Returns `(rssi, alarmLevel)` for the primary RX. `0` when no telemetry.

### Time
```lua
local t = getTime()    -- 10 ms ticks since power-on, integer (32-bit; good for ~497 days, no overflow in practice)
local d = getDateTime()
-- d.year, d.mon, d.day, d.hour, d.min, d.sec
```

Use `getTime()` for measuring durations between frames. **Never** `os.time()` — `os` is not available.

---

## 3. Events (keys and touch)

Only delivered to the script that currently owns the screen (widget in fullscreen, telemetry page, tool, function script doesn't get them).

### Key events
Compare against virtual key constants:

| Constant                  | Trigger                              |
| ------------------------- | ------------------------------------ |
| `EVT_VIRTUAL_ENTER`       | ENTER / wheel-press                  |
| `EVT_VIRTUAL_ENTER_LONG`  | long-press ENTER                     |
| `EVT_VIRTUAL_EXIT`        | RTN / EXIT                           |
| `EVT_VIRTUAL_NEXT`        | scroll right / next                  |
| `EVT_VIRTUAL_NEXT_REPT`   | scroll right, repeating              |
| `EVT_VIRTUAL_PREV`        | scroll left / previous               |
| `EVT_VIRTUAL_PREV_REPT`   | scroll left, repeating               |
| `EVT_VIRTUAL_INC` / `_DEC`| rotary or +/- buttons                |
| `EVT_VIRTUAL_INC_REPT` / `_DEC_REPT` | repeating variant         |
| `EVT_VIRTUAL_MENU`        | MDL / SYS / MENU                     |
| `EVT_VIRTUAL_MENU_LONG`   | long-press MENU                      |
| `EVT_VIRTUAL_NEXT_PAGE` / `_PREV_PAGE` | page navigation         |

Legacy event constants (still present on B/W radios): `EVT_ENTER_BREAK`, `EVT_ENTER_LONG`, `EVT_EXIT_BREAK`, `EVT_MENU_BREAK`, `EVT_PAGE_BREAK`, `EVT_PAGE_LONG`, `EVT_PLUS_BREAK`/`MINUS_BREAK`/`_FIRST`/`_REPT`, `EVT_ROT_LEFT`/`RIGHT`/`BREAK`/`LONG`. Prefer the `EVT_VIRTUAL_*` constants on color radios.

```lua
local function run(event, touchState)
  if event == EVT_VIRTUAL_EXIT then
    return 1   -- exit the script
  end
  if event == EVT_VIRTUAL_ENTER then
    -- toggle something
  end
end
```

`killEvents(event)` swallows further events of that type (useful after handling a long-press to prevent the trailing release).

### Touch events (color touch radios only)

Touch is delivered as **two arguments** to `refresh`/`run`:
1. `event` — one of the touch event constants below (or a regular key event, or `0`/`nil`)
2. `touchState` — table with the touch geometry, or `nil` if the current event is not a touch event

Touch event constants:

| Constant            | Meaning                                            |
| ------------------- | -------------------------------------------------- |
| `EVT_TOUCH_FIRST`   | finger touches down                                |
| `EVT_TOUCH_TAP`     | finger lifts after a quick tap                     |
| `EVT_TOUCH_BREAK`   | finger lifts without a tap or slide               |
| `EVT_TOUCH_SLIDE`   | repeats while finger is sliding                    |

`touchState` fields:

| Field           | When set                | Meaning                              |
| --------------- | ----------------------- | ------------------------------------ |
| `x`, `y`        | always                  | current touch point                  |
| `startX`, `startY` | SLIDE                | point where slide started            |
| `slideX`, `slideY` | SLIDE                | delta since previous SLIDE event     |
| `swipeUp` / `swipeDown` / `swipeLeft` / `swipeRight` | swipe gesture | the matching direction is `true` |
| `tapCount`      | TAP                     | counts consecutive taps              |

**`touchState` does NOT contain an `event` field** — the event is the separate first argument. Always guard with `if touchState then ... end` so the same `refresh`/`run` function works on non-touch radios.

---

## 4. Telemetry & Sensors

### Reading sensors
By name (set in Model → Telemetry → Sensors):
```lua
local cellLow = getValue("Cels")     -- LiPo lowest cell
local vfas    = getValue("VFAS")     -- battery
local altmax  = getValue("Alt+")     -- "+" suffix = max recorded
local altmin  = getValue("Alt-")     -- "-" suffix = min recorded
```

### Telemetry source flags
For sensors that return tables (e.g. multi-cell LiPo `Cels`), the value may be a table; check before using arithmetic on it.

### Resetting telemetry
```lua
model.resetTelemetry()
```

### Pushing custom telemetry (SPort)
```lua
sportTelemetryPush(physicalId, primId, appId, data)
```
Used by tools that emulate a sensor over SPort. `physicalId` 0..27, `primId` 0x10 (DATA_FRAME), `appId` is sensor ID, `data` is 32-bit int.

### Crossfire telemetry
```lua
crossfireTelemetryPush(cmdId, payload)
crossfireTelemetryPop()    -- returns cmd, data array
```

### Audio / haptics (allowed in any script type)
```lua
playFile("/SOUNDS/en/mysound.wav")
playNumber(value, unit [, attr])    -- attr = PREC1, PREC2 for decimals
playTone(freq, duration, pause [, flags])
playHaptic(duration, pause [, flags])
```

### Other useful general functions (often overlooked)
```lua
getVersion()                          -- EdgeTX version string + radio type
getGeneralSettings()                  -- table: language, units, voltage offsets...
getUsage()                            -- 0..100 (%) of the Lua instruction budget used so far
                                      --   in the current execution cycle.
                                      --   Sample at start vs. mid-function to profile a section.
setTelemetryValue(id, subId, ...)     -- inject a custom telemetry sensor value
getSwitchValue(switchIndex)           -- read a switch by index (alternative to getValue("sa"))
getShmVar(id)                         -- shared memory variable read (cross-script)
setShmVar(id, value)                  -- shared memory variable write
serialRead(num)                       -- read from the AUX serial port
serialWrite(data)                     -- write to the AUX serial port
setSerialBaudrate(baudrate)
```

---

## 5. Model API

Read/write the currently active model setup. Most setters take an index plus a table; pass only the fields you want to change.

### Model info
```lua
local info = model.getInfo()
-- info.name, info.bitmap
model.setInfo({ name = "Renamed", bitmap = "/IMAGES/foo.png" })
```

### Inputs (the "I" sources on the radio)
```lua
local count   = model.getInputsCount(input)
local entry   = model.getInput(input, line)
model.insertInput(input, line, params)
model.deleteInput(input, line)
model.deleteInputs()         -- delete all
model.defaultInputs()        -- reset to defaults
```

### Mixes
```lua
local n = model.getMixesCount(channel)
local m = model.getMix(channel, line)
model.insertMix(channel, line, params)
model.deleteMix(channel, line)
model.deleteMixes()
```

### Output channels (servo settings)
```lua
local o = model.getOutput(channel)   -- {name, min, max, offset, ppmCenter, symetrical, revert, curve}
model.setOutput(channel, params)
```

### Curves
```lua
local c = model.getCurve(curveIndex)
-- c.name, c.type (0 = standard, 1 = custom), c.smooth, c.points = {{x,y},...}
model.setCurve(curveIndex, params)
```

### Logical switches / Special functions
```lua
local ls = model.getLogicalSwitch(index)
model.setLogicalSwitch(index, params)
local sf = model.getCustomFunction(index)
model.setCustomFunction(index, params)
```

### Timers
```lua
local t = model.getTimer(timerIndex)    -- 0..2
-- t.mode, t.start, t.value, t.countdownBeep, t.minuteBeep, t.persistent, t.name
model.setTimer(timerIndex, params)
model.resetTimer(timerIndex)
```

### Global Variables (GVARs)
```lua
local gv = model.getGlobalVariable(index, flightMode)   -- 0..8, 0..8
model.setGlobalVariable(index, flightMode, value)
```
GVARs are how you usually hand values from a Lua script into the mix table — the mixer can reference GVx.

### Saving
Most `model.set*` calls take effect immediately *in RAM* but persistent changes require a save on exit or before reboot. EdgeTX typically auto-saves on model switch and on power-off — but for safety after batch edits, prompt the user or rely on the EdgeTX behavior; there is no public `model.save()` exposed in current Lua API.

---

## 6. File I/O

### Paths (SD card root is `/`)

| Path                | Purpose                                    |
| ------------------- | ------------------------------------------ |
| `/SCRIPTS/`         | All script types' folders                  |
| `/SCRIPTS/TOOLS/`   | Tool scripts                               |
| `/SCRIPTS/TELEMETRY/` | Telemetry scripts                        |
| `/SCRIPTS/MIXES/`   | Mix scripts                                |
| `/SCRIPTS/FUNCTIONS/` | Function scripts                         |
| `/WIDGETS/<name>/`  | Widgets (one folder each)                  |
| `/MODELS/`          | Per-model EEPROM-style files (don't touch unless you know) |
| `/LOGS/`            | Telemetry logs (`.csv`)                    |
| `/SOUNDS/<lang>/`   | WAV files for `playFile`                   |
| `/IMAGES/`          | Bitmaps (use `Bitmap.open`)                |

### Available `io.*` functions
EdgeTX exposes a restricted `io` similar to standard Lua:

```lua
local f = io.open(path, mode)
-- mode: "r", "w", "a"  -- always text mode on EdgeTX
if f then
  local data = io.read(f, len_or_"l"_or_"*l"_or_"a")
  io.write(f, "hello\n")
  io.close(f)
end
```

Notes:
- `io.lines`, `io.popen`, `os.execute` are **not** available.
- Path separator is always `/`.
- File handles are an EdgeTX number/userdata — pass them to `io.*` functions, do not call `f:read(...)` method-style (won't work).
- Limit writes — SD card I/O blocks the radio. Avoid per-frame writes.

### JSON
Some EdgeTX builds ship a `libjson` helper as a tool. Generally, write a tiny parser yourself or store data in plain `key=value` lines.

### Persistent settings pattern
Widgets: persist by saving values into the `options` table — EdgeTX serializes those automatically per model.

Tools: save to a file under `/SCRIPTS/TOOLS/<toolname>/state.txt`.

---

## 7. Misc useful globals

| Symbol            | Meaning                                                  |
| ----------------- | -------------------------------------------------------- |
| `LCD_W`, `LCD_H`  | Display width / height in pixels                         |
| `EVT_*`           | Event constants (see Events section)                     |
| `COLOR_THEME_*`   | Theme color constants                                    |
| `SMLSIZE`, `MIDSIZE`, `DBLSIZE`, `XXLSIZE`, `BOLD` | Font flags         |
| `INVERS`, `BLINK`, `SHADOWED` | Text attribute flags                         |
| `LEFT`, `RIGHT`, `CENTER`, `VCENTER` | Alignment flags                       |
| `PREC1`, `PREC2`  | One/two decimal places for `drawNumber`                  |
| `SOLID`, `DOTTED` | Line patterns                                            |
| `FORCE`, `BLINK_ON` | Less common draw modifiers                             |
| `UNIT_*`          | Telemetry unit IDs (`UNIT_VOLTS`, `UNIT_AMPS`, ...)      |
| `MIXSRC_*`        | Numeric IDs for mixer sources, returned by `getFieldInfo` |
