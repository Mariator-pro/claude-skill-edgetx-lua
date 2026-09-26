# Debugging EdgeTX Lua

## Recommended workflow

1. **Edit on the PC**, run in a **simulator** first (VS Code Dev Kit or Companion, see below).
2. Only flash to the radio after the script runs cleanly in the simulator for a few minutes.
3. Keep the previous working version of every file: the simulator + radio combo make "what changed" investigations painful otherwise.

## Simulators

### VS Code: EdgeTX Dev Kit (preferred)

The VS Code extension *EdgeTX Dev Kit* (`jeffreychix.edgetx-dev-kit`, checked with 2.2.2) runs the real EdgeTX firmware compiled to WebAssembly inside VS Code, plus Lua IntelliSense and lint.
- **SD card** = the folder in the setting `edgetx.sdCardPath` (point it at the project's `src/`); radio profile via `.vscode/edgetx.json` / *EdgeTX: Set Radio Profile*.
- **`---@type` annotation** at the top of the file tells the extension the script type: `WidgetScript`, `TelemetryScript`, `FunctionScript`, `MixScript`, `OneTimeScript`.
- **Simulate Script** (right-click / command palette) launches only **widgets** (full main area) and telemetry scripts directly. The documented `---@simulate Layout2x2 zone=1` annotation was **ignored** in a test with 2.2.2 (the widget still ran full size); to test a small zone, set up the layout in the simulator by hand and assign the widget there. Tools are started from the simulator's TOOLS menu.
- **Watch Script** reloads on every save.
- **Logs** pane shows `print()` output and errors; **Telemetry** pane injects fake sensor values.
- Its lint still enforces the old 10-char / no-space limits for widget and option names; those are 2.10 rules (see `script-types.md` → Widget option limits).

### EdgeTX Companion simulator

EdgeTX Companion ships a simulator (`File → Simulate`) with a virtual SD card (point it at a real folder), stick/switch input via the GUI, and a console for `print()` output and Lua errors. Place the script in the matching folder, open the view it belongs to (main view for widgets, TOOLS for tools), edit → save → reload the script (some types need leaving and re-entering the page). Simulating a color radio means no telemetry scripts (B/W only).

## `print()`: your primary debugger

`print(...)` goes to EdgeTX's debug output (`thirdparty/Lua/src/luaconf.h`, `debug.h`, v2.12.4):
- In the simulator: appears in the console / log pane (confirmed in the TX16S MK3 simulator: Logs pane).
- On the radio: **nothing at all** in normal (release) firmware. Only a DEBUG firmware sends it to the serial debug port. There is no `/LOGS/console.log`.

On the radio, use an on-screen overlay (below) or append to your own log file, sparingly (SD writes block the UI):
```lua
local function log(msg)
  local f = io.open("/SCRIPTS/MYAPP/debug.log", "a")
  if f then io.write(f, string.format("%d %s\n", getTime(), msg)); io.close(f) end
end
```

Tips:
- `print(string.format("v=%d t=%d", val, getTime()))`: printf-style is far more useful than concatenation.
- Prefix log lines with your script name: `print("[mywidget] ...")`; many scripts share the same log.
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

`xpcall` with a handler that captures `debug.traceback` would be ideal, but `debug` is not exposed: so you only get the error message, not a stack trace, on the radio. The simulator does print full tracebacks.

## Reproducing on the simulator vs the radio

When something works in the sim but not on the radio:
- Check `LCD_W` / `LCD_H`: the simulator defaults to whatever radio profile you picked.
- Check timing: the simulator runs faster than the radio's CPU; a `getTime()`-based timeout might fire differently.
- Check telemetry: the simulator has no real telemetry; sensors read `0` (e.g. ELRS `RQly`, `1RSS`) until you feed values (Dev Kit: Telemetry pane).

When something works on the radio but not in the sim:
- Touch events behave subtly differently; the sim emulates touch with the mouse.
- File system: the Dev Kit simulator uses the host file system, so `io.open "w"` does not truncate, `rename` overwrites and `mkdir` never fails there, unlike the radio (see `api-reference.md` → Filesystem functions). Verify file logic on the radio.
- File paths: the radio matches case-insensitively, a simulator on a case-sensitive host (Linux) does not, so a wrongly cased path can fail only in the sim.
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
