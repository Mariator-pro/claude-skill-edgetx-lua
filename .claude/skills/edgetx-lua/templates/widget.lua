-- Minimal EdgeTX widget template.
-- Place this file as:   /WIDGETS/MyWidget/main.lua
-- Optionally add an icon:  /WIDGETS/MyWidget/icon.png
--
-- The widget shows the value of a user-selected source as a centered number,
-- with a colored bar underneath that fills proportionally to its [Min..Max] range.
--
-- Limits (EdgeTX 2.10 baseline):
--   * widget name (below): max 10 chars
--   * option name: max 10 chars, NO SPACES
--   * max 5 options (10 from EdgeTX 2.11+)
--   * STRING option default: max 8 chars (12 from 2.11+)

local options = {
  { "Source", SOURCE, 0                       },
  { "Min",    VALUE,  -1024, -1024, 1024      },
  { "Max",    VALUE,   1024, -1024, 1024      },
  { "Color",  COLOR,  COLOR_THEME_FOCUS       },
}

-- Per-instance state. EdgeTX can create multiple widgets from this script;
-- never store state in module-level locals.
local function create(zone, options)
  local widget = {
    zone     = zone,
    options  = options,
    value    = 0,
    label    = "",
  }
  -- Cache the source label once
  local info = getFieldInfo(options.Source)
  widget.label = info and info.name or "?"
  return widget
end

local function update(widget, options)
  widget.options = options
  local info = getFieldInfo(options.Source)
  widget.label = info and info.name or "?"
end

local function background(widget)
  -- Called when the widget is not visible. No lcd.* allowed here.
  widget.value = getValue(widget.options.Source)
end

local function refresh(widget, event, touchState)
  -- Widgets draw in ZONE-LOCAL coordinates: (0,0) is the top-left of the zone,
  -- so use zone.w/zone.h for sizing and stay within 0..w / 0..h. There is no
  -- need to add zone.x/zone.y (they are effectively 0 on modern EdgeTX).
  local z = widget.zone

  -- Always read inside refresh too, in case background() didn't run recently
  local v = getValue(widget.options.Source)
  widget.value = v

  -- Header label
  lcd.drawText(4, 2, widget.label,
               SMLSIZE + COLOR_THEME_SECONDARY1)

  -- Centered value
  local txt = tostring(math.floor(v))
  local tw, th = lcd.sizeText(txt, DBLSIZE + BOLD)
  lcd.drawText((z.w - tw) / 2,
               (z.h - th) / 2 - 4,
               txt,
               DBLSIZE + BOLD + COLOR_THEME_PRIMARY1)

  -- Proportional bar
  local lo, hi = widget.options.Min, widget.options.Max
  if hi > lo then
    local pct = (v - lo) / (hi - lo)
    if pct < 0 then pct = 0 elseif pct > 1 then pct = 1 end
    local barW = math.floor((z.w - 8) * pct)
    lcd.drawFilledRectangle(4, z.h - 6, barW, 4, widget.options.Color)
  end

  -- When the widget is in fullscreen mode, event/touchState will be set.
  if event and event == EVT_VIRTUAL_EXIT then
    -- nothing to clean up
  end
end

return {
  name       = "MyWidget",
  options    = options,
  create     = create,
  update     = update,
  refresh    = refresh,
  background = background,
}
