-- TNS|My Tool|TNE
--
-- Minimal EdgeTX TOOLS-menu script template.
-- Place as:  /SCRIPTS/TOOLS/mytool.lua  (or /SCRIPTS/TOOLS/mytool/main.lua)
-- EdgeTX takes the menu name from between the literal TNS| and |TNE
-- markers above; they must lie within the first 1024 bytes. Without
-- them the menu shows the file name.
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

local STICK_LABELS  = { "Thr", "Rud", "Ele", "Ail" }
local STICK_SOURCES = { "thr", "rud", "ele", "ail" }

local function drawSticks()
  -- Row height from the real font height: fonts are larger on 800x480 radios
  local _, rowH = lcd.sizeText("0", MIDSIZE)
  local top = rowH + 8
  for i = 1, #STICK_LABELS do
    local y = top + (i - 1) * (rowH + 4)
    lcd.drawText(10, y, STICK_LABELS[i], MIDSIZE + COLOR_THEME_SECONDARY1)
    lcd.drawNumber(LCD_W - 10, y, getValue(STICK_SOURCES[i]),
                   MIDSIZE + RIGHT + COLOR_THEME_PRIMARY1)
  end
end

local function run(event, touchState)
  lcd.clear()

  -- No BOLD with a size (MIDSIZE + BOLD = DBLSIZE); highlight by color instead
  lcd.drawText(LCD_W / 2, 4, "MY TOOL",
               MIDSIZE + CENTER + COLOR_THEME_FOCUS)

  drawSticks()

  local _, rowH = lcd.sizeText("0", MIDSIZE)
  lcd.drawText(10, LCD_H - rowH - 4, "Counter: " .. state.counter,
               MIDSIZE + COLOR_THEME_PRIMARY1)
  lcd.drawText(LCD_W - 10, LCD_H - rowH - 4, "ENT = +1   RTN = exit",
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
