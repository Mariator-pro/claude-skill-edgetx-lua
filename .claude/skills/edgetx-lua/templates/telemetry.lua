-- Minimal EdgeTX fullscreen telemetry script template.
-- B/W RADIOS ONLY (Taranis family, 128x64). Color radios have no telemetry
-- scripts; use a widget in fullscreen mode instead (templates/widget.lua).
-- Not tested on hardware.
-- Place as:  /SCRIPTS/TELEMETRY/mytlm.lua
--   (IMPORTANT: filename without .lua must be 6 characters or less!
--    `mytelem.lua` would be SILENTLY ignored by EdgeTX.)
-- Then in Model Setup -> Display, add a screen of type "Script" and pick this file.
--
-- Shows ELRS link quality, RSSI, battery (RxBt) and altitude in a 2x2 grid.
-- B/W radios have no COLOR_THEME_* constants (they would be nil and crash);
-- use plain flags only. BOLD is a real bold attribute here.

local state = {
  lastUpdate = 0,
  rqly       = 0,
  rssi       = 0,
  rxBatt     = 0,
  altitude   = 0,
}

local function init()
  -- Called once when the page is first opened.
  state.lastUpdate = getTime()
end

local function readSensors()
  state.rqly     = getValue("RQly") or 0
  state.rssi     = getValue("1RSS") or 0
  state.rxBatt   = getValue("RxBt") or 0
  state.altitude = getValue("Alt")  or 0
end

local function drawCell(x, y, w, h, label, text)
  lcd.drawText(x + 2, y + 2, label, SMLSIZE)
  lcd.drawText(x + w - 2, y + h - 10, text, SMLSIZE + BOLD + RIGHT)
  lcd.drawRectangle(x, y, w, h)
end

local function run(event)
  -- Cheap rate-limit: only re-read sensors every 100 ms (10 ticks)
  if getTime() - state.lastUpdate > 10 then
    readSensors()
    state.lastUpdate = getTime()
  end

  lcd.clear()
  lcd.drawText(LCD_W / 2, 0, "TELEMETRY", SMLSIZE + INVERS + CENTER)

  -- 2x2 grid below the title
  local top   = 9
  local cellW = math.floor(LCD_W / 2)
  local cellH = math.floor((LCD_H - top) / 2)

  drawCell(0,     top,         cellW, cellH, "RQly", string.format("%d%%", math.floor(state.rqly)))
  drawCell(cellW, top,         cellW, cellH, "1RSS", string.format("%ddBm", math.floor(state.rssi)))
  drawCell(0,     top + cellH, cellW, cellH, "RxBt", string.format("%.1fV", state.rxBatt))
  drawCell(cellW, top + cellH, cellW, cellH, "Alt",  string.format("%dm", math.floor(state.altitude)))
  return 0
end

local function background()
  -- Optional: keep sensors fresh even when this page is not active.
  -- No lcd.* allowed here.
  readSensors()
end

return {
  init       = init,
  run        = run,
  background = background,
}
