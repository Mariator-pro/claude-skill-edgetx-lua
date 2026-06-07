# Debugging EdgeTX Lua

## Recommended workflow

1. **Edit on the PC**, run in the **EdgeTX Companion simulator** first.
2. Only flash to the radio after the script runs cleanly in the simulator for a few minutes.
3. Keep the previous working version of every file — the simulator + radio combo make "what changed" investigations painful otherwise.

## EdgeTX Companion simulator

EdgeTX Companion ships with a simulator (`File → Simulate`) that emulates the radio. It supports:
- All script types
- A virtual SD card (point it at a real folder on the PC)
- Stick/switch/pot input via the GUI or mapped USB controllers
- A console window that captures `print()` output and Lua errors with stack traces

Workflow:
1. Set the simulator's SD card path to your dev folder (so file edits are picked up without copying).
2. Place your script in the matching folder (e.g. `WIDGETS/MyWidget/main.lua`).
3. Open the simulator, switch to the appropriate view (Main, Telemetry, Tools).
4. Watch the console for `print()` output and tracebacks.
5. Edit → save → simulator picks up the change on next script reload (some script types need exiting and re-entering the page).

## `print()` — your primary debugger

`print(...)` writes to the EdgeTX log:
- In the simulator: appears in the Console pane.
- On the radio: written to `/LOGS/console.log` (newer EdgeTX) or visible in `dmesg` over USB on some builds. **Not visible on the radio screen.**

Tips:
- `print(string.format("v=%d t=%d", val, getTime()))` — printf-style is far more useful than concatenation.
- Prefix log lines with your script name: `print("[mywidget] ...")` — many scripts share the same log.
- Rate-limit prints: do not `print` every frame. Use a counter or only print on state changes.

## On-screen debug overlay

When you cannot use the simulator (e.g. script behaves differently on hardware), draw debug info into a spare corner:

```lua
local function refresh(widget)
  -- ... normal drawing ...
  -- debug overlay (remove before release)
  lcd.drawText(0, 0, tostring(widget.lastVal),   -- zone-local: (0,0) = zone corner
               SMLSIZE + COLOR_THEME_WARNING)
end
```

Use `COLOR_THEME_WARNING` so the overlay stands out and you don't ship it accidentally.

## Catching errors with `pcall`

A single uncaught error halts the script. Wrap suspect blocks:

```lua
local ok, err = pcall(function()
  doRiskyThing()
end)
if not ok then
  print("[mywidget] error: " .. tostring(err))
  -- show on screen so you notice
  lcd.drawText(0, 0, tostring(err), SMLSIZE + COLOR_THEME_WARNING)
end
```

`xpcall` with a handler that captures `debug.traceback` would be ideal, but `debug` is not exposed — so you only get the error message, not a stack trace, on the radio. The simulator does print full tracebacks.

## Reproducing on the simulator vs the radio

When something works in the sim but not on the radio:
- Check `LCD_W` / `LCD_H` — the simulator defaults to whatever radio profile you picked.
- Check timing: the simulator runs faster than the radio's CPU; a `getTime()`-based timeout might fire differently.
- Check file paths: the simulator is more permissive about casing on macOS/Linux (depending on filesystem).
- Check telemetry: there is no real telemetry in the simulator unless you enable simulated telemetry — `getValue("RSSI")` will be `0`.

When something works on the radio but not in the sim:
- Touch events behave subtly differently; the sim emulates touch with the mouse.
- Bitmap rendering on the sim can be slightly different (scaling / alpha).

## Useful one-liners

Measure a section's duration:
```lua
local t0 = getTime()
heavyWork()
print(string.format("heavy=%d ticks", getTime() - t0))   -- in 10 ms units
```

Dump a table:
```lua
local function dump(t, indent)
  indent = indent or ""
  for k, v in pairs(t) do
    if type(v) == "table" then
      print(indent .. tostring(k) .. ":")
      dump(v, indent .. "  ")
    else
      print(indent .. tostring(k) .. " = " .. tostring(v))
    end
  end
end
dump(model.getInfo())
```

Force garbage collection during init to see real memory baseline:
```lua
collectgarbage("collect")
print("mem=" .. collectgarbage("count") .. "kb")
```

## Verification checklist before considering a script "done"

- [ ] Runs in the simulator without errors for at least one minute.
- [ ] No `print` calls left on hot paths (`run`/`refresh`).
- [ ] No debug overlay text drawn in the released version.
- [ ] Coordinates derived from `LCD_W`/`LCD_H` or zone, not hard-coded.
- [ ] Behaves sanely when telemetry is missing (`getValue` returns 0).
- [ ] `pcall` around any external file/IO or bitmap loads.
- [ ] If a widget: tested with multiple instances on screen.
- [ ] Confirmed on at least one real radio if the script will be shared.
