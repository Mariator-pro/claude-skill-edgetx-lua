# EdgeTX Lua API Reference

Condensed reference of the EdgeTX-specific APIs most often needed when writing scripts. For which source wins on conflicts, see `SKILL.md` → Source of truth (EdgeTX source code first, then observed behaviour, then the official guide).

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
lcd.drawNumber(x, y, value [, flags])      -- integer; PREC1/PREC2 = decimal places (235 + PREC1 -> 23.5, confirmed in the TX16S MK3 simulator)
lcd.drawTimer(x, y, seconds [, flags])     -- "MM:SS" style; add TIMEHOUR to include hours
lcd.sizeText(text [, flags]) -> w, h       -- measure before drawing
```

Common `flags` (OR them together). Availability per `api_general.cpp`, v2.12.4:

| Flag                  | Meaning                                  | Notes              |
| --------------------- | ---------------------------------------- | ------------------ |
| `TINSIZE`             | tiny font                                | color only         |
| `SMLSIZE`             | small font                               |                    |
| `STDSIZE`             | standard font (same as no size flag)     | color only         |
| `MIDSIZE`             | medium font                              |                    |
| `DBLSIZE`             | double-height font                       |                    |
| `XLSIZE`              | between `DBLSIZE` and `XXLSIZE`          | color only         |
| `XXLSIZE`             | extra-large font ("jumbo")               |                    |
| `BOLD`                | bold                                     | both; on color radios only bold at standard size (see pitfalls.md → font table) |
| `INVERS`              | swap fg/bg (highlight)                   |                    |
| `BLINK`               | blinking text                            |                    |
| `LEFT`                | left-justify (default)                   |                    |
| `RIGHT`               | right-justify                            |                    |
| `CENTER`              | horizontally center                      | both               |
| `VCENTER`             | vertically center on `y`                 | color only         |
| `VTOP` / `VBOTTOM`    | vertical alignment on `y`                | color only. `VTOP` is `0` (no effect, text top at `y` is the default). **`VBOTTOM` is `0x200`, inside the font bits: it changes the font** (`SMLSIZE + VBOTTOM` = `DBLSIZE`); don't use it (`libopenui_defines.h`, v2.12.4; confirmed in the simulator) |
| `SHADOWED`            | drop-shadow                              | color only (confirmed in the TX16S MK3 simulator, as are `INVERS`, `BLINK`) |
| `FIXEDWIDTH`          | fixed-width font                         | B/W only           |
| `FORCE`               | force black pixels                       | B/W, `LCD_W <= 212` only |
| `ERASE`               | force white pixels                       | B/W, `LCD_W <= 212` only |
| `GREY_DEFAULT`        | grey fill                                | B/W greyscale displays only |
| `TIMEHOUR`            | include hours in `drawTimer`             | `drawTimer` only; 3725 s shows as `01h02:05` (confirmed in the TX16S MK3 simulator) |

Color is passed by OR-ing a color constant into `flags`, or via `lcd.setColor` / explicit color arg on newer EdgeTX:

```lua
lcd.drawText(10, 10, "Hi", SMLSIZE + COLOR_THEME_PRIMARY1)
```

### Theme colors (preferred: adapt to user's theme)
```
COLOR_THEME_PRIMARY1   COLOR_THEME_PRIMARY2   COLOR_THEME_PRIMARY3
COLOR_THEME_SECONDARY1 COLOR_THEME_SECONDARY2 COLOR_THEME_SECONDARY3
COLOR_THEME_FOCUS      COLOR_THEME_EDIT       COLOR_THEME_ACTIVE
COLOR_THEME_WARNING    COLOR_THEME_DISABLED
CUSTOM_COLOR                                  -- writable via lcd.setColor
```

Theme colors are **indexed**: changing one (e.g. with a custom theme) changes it everywhere it is used.

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
lcd.drawRectangle(x, y, w, h [, flags [, thickness [, opacity]]])   -- opacity as below (api_colorlcd.cpp, v2.12.4)
lcd.drawFilledRectangle(x, y, w, h, flags [, opacity])
   -- opacity 0..15, INVERTED scale: 0 = fully opaque (default), 15 = not drawn at all,
   -- alpha = (15 - opacity) / 15, so 8 is about half-transparent. Masked to 4 bits (16 -> 0).
   -- (confirmed in the TX16S MK3 simulator)
   -- Color radios only (api_colorlcd.cpp / bitmapbuffer.cpp, v2.12.4).
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
Cache bitmaps in `init`/`create`; do not call `Bitmap.open` per frame: it's slow and leaks memory.

### Clipping
There is **no general clipping call** (no `lcd.setClipping`; confirmed nil in the simulator). Only lines have one:
```lua
lcd.drawLineWithClipping(x1, y1, x2, y2, xmin, xmax, ymin, ymax, pattern [, flags])
```
Widgets don't need it: EdgeTX clips every widget's drawing to its own zone automatically (`lua_widget.cpp`, v2.12.4). (confirmed in the TX16S MK3 simulator)

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
- the **GPS sensor, by its sensor name** (`getValue("GPS")` with ELRS/CRSF) → `{ lat=..., lon=..., ["pilot-lat"]=..., ["pilot-lon"]=... }` (positive = N/E). `"latitude"`/`"longitude"` are *not* source names (they return 0; confirmed in the TX16S MK3 simulator).
- GPS date/time → table in the same shape as `getDateTime()`
- `getDateTime()` also has `hour12` and `suffix` ("am"/"pm") (confirmed in the TX16S MK3 simulator)
- `"Cels"` (multi-cell LiPo) → array of per-cell voltages. `"Cels+"` / `"Cels-"` return a single number: the highest / lowest value *recorded since reset* (like `"Alt+"`/`"Alt-"`), not the current highest/lowest cell.

Always `type()`-check before doing arithmetic on a sensor result you have not confirmed is a number.

Common source name patterns:
- Sticks: `thr`, `rud`, `ele`, `ail`
- Trims: `trim-thr` etc.
- Pots/Sliders: `s1`, `s2`, `ls`, `rs`
- Switches: `sa`, `sb`, ..., `sh`; return `-1024`/`0`/`+1024` for 3-pos (confirmed in the TX16S MK3 simulator)
- Logical Switches: `ls1`...`ls64`; return **`-1024` (off) / `+1024` (on)**, never 0/1; test with `> 0`, or use `getLogicalSwitchValue(n)` (0 = L1) for a boolean
- Trainer inputs: `trn1`..`trn16` (`tr1` and `tx-time` do not exist: `api_general.cpp`, v2.12.4; confirmed in the TX16S MK3 simulator)
- Channels: `ch1`..`ch32`; output channel values
- Special: `clock` (RTC, minutes since midnight), `tx-voltage`, `min`, `max`
- Numbered: `input1`.., `gvar1`.., `timer1`.. (seconds), `telem1`.. (sensor slot), `lua1`.. (mix-script outputs)
- Telemetry sensors: by the name set in Model → Telemetry. Names depend on the protocol and exist only after discovery: `RSSI`/`RAS` are FrSky, ELRS/CRSF uses e.g. `1RSS`, `RQly`, `RxBt`. They are not fixed sources.

Value scale conventions:
- Sticks / pots / channels: `-1024` (full negative) to `+1024` (full positive)
- Logical switches: `-1024` (off) or `+1024` (on) (`mixer.cpp`, v2.12.4; confirmed in the TX16S MK3 simulator); `== 1` is never true, `~= 0` is always true
- Sensor values: native units (V, A, m/s, m, °, ...); depends on sensor

### `getSourceValue(source)` → value, isCurrent, isFresh (preferred for telemetry)
Successor of `getValue` (`api_general.cpp`, v2.12.4; since 2.8, present in 2.11.0). Same source names/ids and same table results (GPS, cells, date/time), but it tells "missing", "zero" and "stale" apart:
- returns **no value** if the source does not exist or the sensor has **never been received** (so `v == nil` means missing, `0` is a real 0)
- `isCurrent`: `true` while the sensor is within its "sensor lost" time and telemetry is streaming; after a link loss you still get the **last known value** with `isCurrent == false`
- `isFresh`: `true` if the value was just updated
- non-telemetry sources: both flags always `true`; `tx-voltage` comes back in volts
- confirmed in the TX16S MK3 simulator: no value without telemetry, `100, true, true` live, `100, false, false` after the link stopped (while `getValue` gave 0)
```lua
local v, isCurrent = getSourceValue("RQly")
if v == nil then        -- sensor missing / never seen
elseif not isCurrent then -- stale: link lost, v is the last known value
else                      -- live value (0 is a real 0)
end
```

### `getFieldInfo(nameOrId)`
```lua
local info = getFieldInfo("thr")
-- info.id, info.name, info.desc, info.unit
```
Use `id` for repeated `getValue` calls in hot paths.

### `getRSSI()` → rssi, alarmLow, alarmCrit
Returns **three** values: the RSSI (`0` when no link), the configured low alarm level and the configured critical alarm level (`api_general.cpp`, v2.12.4; confirmed in the TX16S MK3 simulator). This is the FrSky-style RSSI; with ELRS/CRSF read the sensors (`1RSS`, `RQly`) instead.

### Time
```lua
local t = getTime()    -- 10 ms ticks since power-on, integer (32-bit; good for ~497 days, no overflow in practice)
local d = getDateTime()
-- d.year, d.mon, d.day, d.hour, d.min, d.sec
```

Use `getTime()` for measuring durations between frames. **Never** `os.time()`: `os` is not available.

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
| `EVT_VIRTUAL_NEXT_REPT`   | scroll right, repeating (*key radios only, see below*) |
| `EVT_VIRTUAL_PREV`        | scroll left / previous               |
| `EVT_VIRTUAL_PREV_REPT`   | scroll left, repeating (*key radios only*) |
| `EVT_VIRTUAL_INC` / `_DEC`| rotary or +/- buttons                |
| `EVT_VIRTUAL_INC_REPT` / `_DEC_REPT` | repeating variant (*key radios only*) |
| `EVT_VIRTUAL_MENU`        | MENU key; on TX16S the MDL key (short; confirmed in the TX16S MK3 simulator) |
| `EVT_VIRTUAL_MENU_LONG`   | long-press MENU (TX16S: MDL)         |
| `EVT_VIRTUAL_NEXT_PAGE` / `_PREV_PAGE` | page navigation         |

**Which constants exist depends on the radio's keys** (`radio/util/hw_defs/lua_keys.jinja`, v2.12.4; confirmed in the TX16S MK3 simulator: `EVT_VIRTUAL_NEXT_REPT` is nil). On radios with a **rotary encoder** (TX16S, TX15, most color radios) `NEXT`/`PREV`/`INC`/`DEC` come from the wheel and the **`_REPT` variants do not exist: they are `nil`**. Only radios with +/- or arrow keys have them.

Trap: in a widget `event` is also `nil` outside fullscreen, so `event == EVT_VIRTUAL_NEXT_REPT` is `nil == nil` → **true on every frame**. Always guard with `if event then ... end` (or check the constant is not `nil`) before comparing.

Legacy per-key constants exist **depending on the radio's keys, on color radios too** (`lua_keys.jinja`, v2.12.4). On a TX16S (rotary + MDL/SYS/TELE/PAGE keys) for example: `EVT_ENTER_FIRST/BREAK/LONG/REPT`, `EVT_EXIT_BREAK`, `EVT_MODEL_*`, `EVT_SYS_*`, `EVT_TELEM_*`, `EVT_PAGEUP_*`, `EVT_PAGEDN_*`, `EVT_ROT_LEFT`/`EVT_ROT_RIGHT`; `EVT_PLUS_*`/`EVT_MINUS_*` only on radios with +/- keys. Use them to query one specific key (e.g. SYS); otherwise prefer `EVT_VIRTUAL_*`, which have the same names on every radio. (Legacy constants on the Mk III confirmed in the TX16S MK3 simulator; `EVT_PLUS_*` is nil there.)

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

`killEvents(key)` stops the key's event sequence for the **whole key** (only the key part of the value is used). It is **ignored for ENTER and EXIT** (and on some radios PAGE DOWN outside tools), since those keys are never maskable (`api_general.cpp`, v2.12.4). It isn't needed there anyway: a long press delivers exactly one `EVT_VIRTUAL_ENTER_LONG` and **no** short `EVT_VIRTUAL_ENTER` afterwards (confirmed in the TX16S MK3 simulator). Don't "ignore the next ENTER" after a long press, that would swallow a real one.

### Touch events (color touch radios only)

Touch is delivered as **two arguments** to `refresh`/`run`:
1. `event`: one of the touch event constants below (or a regular key event, or `0`/`nil`)
2. `touchState`: table with the touch geometry, or `nil` if the current event is not a touch event

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
| `swipeUp` / `swipeDown` / `swipeLeft` / `swipeRight` | SLIDE, fast only (see below) | the matching direction is `true` |
| `tapCount`      | always (confirmed in the TX16S MK3 simulator) | counts consecutive taps              |

**Swipe detection** (`lua_event.cpp`, v2.12.4): a `swipe*` flag is set only on an `EVT_TOUCH_SLIDE` event whose movement since the previous slide event exceeds **60 px**, in a clear direction (4× more along one axis than the other), and at most **once per 0.5 s**. A slow drag never produces a swipe (confirmed in the TX16S MK3 simulator: 13 px steps gave none, a 366 px step gave `swipeLeft`); detect it yourself.

Event order (simulator): tap = `TOUCH_FIRST` → `TOUCH_TAP`; drag = `TOUCH_FIRST` → `TOUCH_SLIDE` … → `TOUCH_BREAK`. On release the simulator sends a last `TOUCH_SLIDE` **and** the `TOUCH_BREAK` with `x = 0, y = 0` (`tapCount` 0 too); not checked on a radio. So skip zero positions and remember the last valid one:
```lua
if event == EVT_TOUCH_FIRST then w.lastX = nil end
if event == EVT_TOUCH_SLIDE and touchState and not (touchState.x == 0 and touchState.y == 0) then
  w.startX, w.lastX = touchState.startX, touchState.x
end
if event == EVT_TOUCH_BREAK and w.lastX then
  local dx = w.lastX - w.startX
  if math.abs(dx) > 80 then --[[ page left/right by sign of dx ]] end
  w.lastX = nil
end
```

**`touchState` does NOT contain an `event` field**: the event is the separate first argument. Always guard with `if touchState then ... end` so the same `refresh`/`run` function works on non-touch radios.

---

## 4. Telemetry & Sensors

### Reading sensors
By name (set in Model → Telemetry → Sensors):
```lua
local cells   = getValue("Cels")     -- table of all cells {[1]=3.91, [2]=3.90, ...} (0 if none detected)
local lowRec  = getValue("Cels-")    -- lowest value RECORDED since reset, a number ("Cels+" = highest)
-- current lowest cell: take the minimum over the table yourself
local vfas    = getValue("VFAS")     -- battery
local altmax  = getValue("Alt+")     -- "+" suffix = max recorded
local altmin  = getValue("Alt-")     -- "-" suffix = min recorded
```

### Telemetry source flags
For sensors that return tables (e.g. multi-cell LiPo `Cels`), the value may be a table; check before using arithmetic on it.

### Resetting telemetry
```lua
model.resetSensor(sensor)   -- one sensor, 0 = sensor 1; there is no "reset all" call
                            -- (model.resetTelemetry is nil, confirmed in the simulator)
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
getSwitchValue(switchIndex)           -- true/false for ONE switch POSITION (e.g. "SA up"), not -1024/0/1024;
                                      --   index from getSwitchIndex(name as shown in radio menus, incl. arrow chars)
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
local c = model.getCurve(curveIndex)   -- 0 = Curve 1; nil only for an index >= MAX_CURVES
-- c.name, c.type, c.smooth, c.points = NUMBER of points
-- c.y = y values, c.x = x values (x only for custom curves, incl. the fixed ends -100 / 100)
-- Both tables are 1-based despite the luadoc saying "zero based" (the code pushes i + 1;
-- api_model.cpp, v2.12.4; confirmed in the TX16S MK3 simulator: y[0] is nil)
for i = 1, c.points do
  local y = c.y[i]
  local x = c.x and c.x[i]
end
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
GVARs are how you usually hand values from a Lua script into the mix table: the mixer can reference GVx.

### Saving
`model.set*` calls take effect immediately and mark the model as changed; EdgeTX then **writes it to the SD card by itself** after a short delay (2 to 15 s depending on the radio, 15 s on radios with battery-backed RAM, 1 s in the simulator; `storage/storage.h`, v2.12.4). No save call is needed (and there is no `model.save()`). Confirmed in the TX16S MK3 simulator: model written ~1 s after a change.
- Powering off within that delay can lose the last change.
- Don't call `model.set*` every frame: each call restarts the delay and causes SD writes. Write only when a value actually changes.

---

## 6. File I/O

### Paths (SD card root is `/`)

| Path                | Purpose                                    |
| ------------------- | ------------------------------------------ |
| `/SCRIPTS/`         | All script types' folders                  |
| `/SCRIPTS/TOOLS/`   | Tool scripts                               |
| `/SCRIPTS/TELEMETRY/` | Telemetry scripts (B/W radios only)    |
| `/SCRIPTS/MIXES/`   | Mix scripts                                |
| `/SCRIPTS/FUNCTIONS/` | Function scripts                         |
| `/WIDGETS/<name>/`  | Widgets (one folder each)                  |
| `/MODELS/`          | Model settings as YAML text (`model00.yml`, `labels.yml`); written by the radio, don't edit from scripts |
| `/RADIO/`           | Radio settings (`radio.yml`)               |
| `/THEMES/`          | Color themes (see `themes.md`)             |
| `/LOGS/`            | Telemetry logs (`.csv`)                    |
| `/SOUNDS/<lang>/`   | WAV files for `playFile`                   |
| `/IMAGES/`          | Bitmaps (use `Bitmap.open`)                |

### Available `io.*` functions
EdgeTX exposes a restricted `io` similar to standard Lua:

```lua
local f = io.open(path, mode)
-- mode: "r", "w", "a"  -- always text mode on EdgeTX
if f then
  local data = io.read(f, n)   -- up to n BYTES; "" at end of file
  io.write(f, "hello\n")
  io.close(f)
end
```

**`io.read` only takes a byte count.** EdgeTX replaced the standard reader (`liolib.c`, v2.12.4; confirmed in the TX16S MK3 simulator): the second argument is always read as a number of bytes. `"l"`, `"*l"`, `"a"` or no argument become `0` and **silently return `""`**: no error, just nothing. Read whole files in blocks and split lines yourself:
```lua
local function readAll(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local parts = {}
  while true do
    local chunk = io.read(f, 1024)
    if chunk == "" then break end
    parts[#parts + 1] = chunk
  end
  io.close(f)
  return table.concat(parts)
end
-- lines: for line in string.gmatch(text, "[^\n]+") do ... end
```
For structured data, writing the file as a Lua table (`return { ... }`) and loading it with `loadScript` avoids parsing altogether.

Notes:
- `io.lines`, `io.popen`, `os.execute` are **not** available.
- Path separator is always `/`.
- File handles are an EdgeTX number/userdata: pass them to `io.*` functions, do not call `f:read(...)` method-style (won't work).
- Limit writes: SD card I/O blocks the radio. Avoid per-frame writes.
- `"w"` maps to FatFs `FA_WRITE | FA_CREATE_ALWAYS`: create and **truncate** (`liolib.c`, v2.12.4; confirmed on a real radio). The VS Code simulator does *not* truncate, see the warning under the filesystem table.

### Filesystem functions (globals, all script types)
There is **no `os` library**: `os.remove`, `os.rename`, `os.time` etc. do not exist. EdgeTX provides its own globals instead (`radio/src/lua/api_filesystem.cpp`, v2.12.4):

| Function | Since | Returns |
| --- | --- | --- |
| `fstat(path)` | 2.5.0 | table `{size, attrib, time}`, or **no value at all** if missing: the way to test existence (don't probe with `io.open`) (confirmed on a real radio) |
| `del(path)` | 2.9.0 | FRESULT: deletes a file or empty folder (confirmed on a real radio: 0 file, 7 non-empty folder, 0 empty folder) |
| `rename(from, to)` | 2.11.0 | FRESULT: rename or move; target parent must exist, **does not overwrite** an existing target (8) (confirmed on a real radio: 8 onto existing, 5 into missing folder) |
| `mkdir(path)` | 2.11.0 | FRESULT: creates a folder (8 if it exists) (confirmed on a real radio) |
| `chdir(path)` | 2.3.0 | nothing |

"No value" behaves like `nil` in `if fstat(p)`, `fstat(p) == nil` or `local x = fstat(p)`, but passed straight on as an argument it is *missing*: `tostring(fstat(p))` throws "bad argument #1 to 'tostring' (value expected)". Wrap it: `tostring((fstat(p)))`. `del` and `fstat` confirmed in the TX16S MK3 simulator.

> **The VS Code simulator (EdgeTX Dev Kit 2.2.2) does not behave like the radio here.** It maps files to the host file system via Node.js (`fsWorker.js` of the extension): `io.open(p, "w")` does **not** truncate (writing `"abc"` over `"1234567890"` leaves `"abc4567890"`), `rename` **overwrites** an existing target and creates missing folders, `mkdir` returns 0 for an existing folder. The radio follows FatFs as in the table (confirmed on a real radio). Test file logic on the radio; for code that must behave the same in both, `del(path)` before writing.

FRESULT codes: `0` OK, `4` file not found, `5` path not found, `6` invalid path, `8` already exists.
```lua
if fstat("/SCRIPTS/TOOLS/OLD.lua") then del("/SCRIPTS/TOOLS/OLD.lua") end
```

### Listing a directory: `dir(path)`
Iterator over the entries in a folder (available since OpenTX/EdgeTX 2.5.0). Each iteration yields a **plain filename string**: not a path:

```lua
for fname in dir("/SOUNDS/en/scripts/LIPONY") do
  -- fname is a string, e.g. "warn.wav"
end
```

Notes:
- Pass the path **without a trailing slash**.
- Yields **bare filenames** (strings), not full paths: prepend the folder yourself if you need a path.
- **Throws if the folder does not exist**: wrap in `pcall` when the folder may be missing. (confirmed in the TX16S MK3 simulator)
- Filter with the free string functions, not method syntax (see pitfalls.md): `string.match(string.lower(fname), "%.wav$")`, **not** `fname:lower():match(...)`.

Reference: <https://luadoc.edgetx.org/lua-api-reference/filesystem/dir>

### JSON
There is no JSON support built in. Simplest is to store data as a Lua table (`return { ... }`) and load it with `loadScript` (see Persistent settings pattern), no parser needed.

### Persistent settings pattern
**Widget `options` are read-only for the script.** EdgeTX copies the stored settings *into* the `options` table (on `create` and when the user edits the dialog, then calls `update`); nothing flows back (`lua_widget.cpp`, v2.12.4). Values a script writes into `options` are never saved and get overwritten on the next `update`. Use options only for what the user sets in the dialog. (confirmed in the TX16S MK3 simulator)

Script-owned data (counters, home position, learned values) goes into your own file, for widgets and tools alike, e.g. `/SCRIPTS/<NAME>/config.lua`: write it with `io.write` (ideally as `return { ... }`) and read it back with `loadScript` or the `readAll` pattern above. Avoid storing data inside `/SCRIPTS/TOOLS/`: a subfolder there that contains `main.lua` shows up as a tool itself.

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
| `FORCE`           | Less common draw modifier (B/W radios with `LCD_W <= 212` only) |
| `UNIT_*`          | Telemetry unit IDs (`UNIT_VOLTS`, `UNIT_AMPS`, ...)      |
| `MIXSRC_*`        | Numeric IDs for mixer sources, returned by `getFieldInfo` |
