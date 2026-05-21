-- Minimal EdgeTX fullscreen telemetry script template.
-- Place as:  /SCRIPTS/TELEMETRY/mytlm.lua
--   (IMPORTANT: filename without .lua must be 6 characters or less!
--    `mytelem.lua` would be SILENTLY ignored by EdgeTX.)
-- Then in Model Setup -> Display, add a screen of type "Script" and pick this file.
--
-- Shows RSSI, battery (RxBt), and a custom sensor in a 2x2 grid.

local state = {
  lastUpdate = 0,
  rssi       = 0,
  rxBatt     = 0,
  altitude   = 0,
}

local function init()
  -- Called once when the page is first opened.
  state.lastUpdate = getTime()
end

local function readSensors()
  state.rssi     = getValue("RSSI")  or 0
  state.rxBatt   = getValue("RxBt")  or 0
  state.altitude = getValue("Alt")   or 0
end

local function drawCell(x, y, w, h, label, value, unit, color)
  lcd.drawText(x + 4, y + 2, label, SMLSIZE + COLOR_THEME_SECONDARY1)
  local txt = tostring(value) .. (unit or "")
  lcd.drawText(x + w - 4, y + h / 2 - 2, txt,
               MIDSIZE + BOLD + RIGHT + (color or COLOR_THEME_PRIMARY1))
  lcd.drawRectangle(x, y, w, h, COLOR_THEME_SECONDARY3)
end

local function run(event, touchState)
  -- Cheap rate-limit: only re-read sensors every 100 ms (10 ticks)
  if getTime() - state.lastUpdate > 10 then
    readSensors()
    state.lastUpdate = getTime()
  end

  lcd.clear()

  -- Title
  lcd.drawText(LCD_W / 2, 4, "TELEMETRY",
               MIDSIZE + BOLD + CENTER + COLOR_THEME_PRIMARY1)

  -- 2x2 grid below title
  local top   = 30
  local cellW = LCD_W / 2
  local cellH = (LCD_H - top) / 2

  drawCell(0,         top,           cellW, cellH, "RSSI", state.rssi, "dB")
  drawCell(cellW,     top,           cellW, cellH, "RxBt", state.rxBatt, "V")
  drawCell(0,         top + cellH,   cellW, cellH, "Alt",  state.altitude, "m")
  drawCell(cellW,     top + cellH,   cellW, cellH, "Time", math.floor(getTime() / 100), "s")

  -- Exit on RTN key
  if event == EVT_VIRTUAL_EXIT then
    return 1
  end
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
