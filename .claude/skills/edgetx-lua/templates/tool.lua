---- #TNS# "My Tool"
---- #TNE#
--
-- Minimal EdgeTX TOOLS-menu script template.
-- Place as:  /SCRIPTS/TOOLS/mytool.lua
-- The #TNS#/#TNE# markers above are scanned by EdgeTX to populate
-- the TOOLS menu without parsing the whole file. Keep them on the
-- very first two non-blank lines.
--
-- This tool shows current stick positions and lets the user toggle
-- a counter with ENTER, exit with RTN.

local state = {
  counter   = 0,
  lastEnter = 0,
}

local function init()
  state.counter = 0
end

local function drawSticks()
  local sticks = {
    { name = "Thr", v = getValue("thr") },
    { name = "Rud", v = getValue("rud") },
    { name = "Ele", v = getValue("ele") },
    { name = "Ail", v = getValue("ail") },
  }
  for i, s in ipairs(sticks) do
    local y = 30 + (i - 1) * 24
    lcd.drawText(10, y, s.name, MIDSIZE + COLOR_THEME_SECONDARY1)
    lcd.drawNumber(LCD_W - 10, y, s.v,
                   MIDSIZE + BOLD + RIGHT + COLOR_THEME_PRIMARY1)
  end
end

local function run(event, touchState)
  lcd.clear()

  lcd.drawText(LCD_W / 2, 4, "MY TOOL",
               MIDSIZE + BOLD + CENTER + COLOR_THEME_PRIMARY1)

  drawSticks()

  lcd.drawText(10, LCD_H - 24, "Counter: " .. state.counter,
               MIDSIZE + COLOR_THEME_PRIMARY1)
  lcd.drawText(LCD_W - 10, LCD_H - 24, "ENT = +1   RTN = exit",
               SMLSIZE + RIGHT + COLOR_THEME_SECONDARY1)

  if event == EVT_VIRTUAL_ENTER then
    state.counter = state.counter + 1
  elseif event == EVT_VIRTUAL_EXIT then
    return 1   -- exit the tool
  end

  return 0
end

return {
  init = init,
  run  = run,
}
