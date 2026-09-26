-- Minimal EdgeTX widget template.
-- Place this file as:   /WIDGETS/MyWidget/main.lua
-- Optionally add an icon:  /WIDGETS/MyWidget/icon.png
--
-- The widget shows the value of a user-selected source as a centered number,
-- with a colored bar underneath that fills proportionally to its [Min..Max] range.
--
-- Limits (verified in source, see script-types.md -> Widget option limits):
--   * folder name max 13 chars; widget name <= 20 chars on 2.11 (no limit on 2.12)
--   * option names: no hard limit since 2.11; keep them space-free (options.Name)
--   * max 10 options on 2.11, 50 on 2.12; STRING option 12 / 255 chars
--   * BOOL options are 0/1: test with == 1 (0 is truthy in Lua)

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
  -- need to add zone.x/zone.y (they are always 0 on EdgeTX).
  local z = widget.zone

  -- Always read inside refresh too, in case background() didn't run recently
  local v = getValue(widget.options.Source)
  widget.value = v

  -- Header label
  lcd.drawText(4, 2, widget.label,
               SMLSIZE + COLOR_THEME_SECONDARY1)

  -- Centered value
  local txt = tostring(math.floor(v))
  -- DBLSIZE is bold by design; never add BOLD to a size (DBLSIZE + BOLD = XXLSIZE)
  local tw, th = lcd.sizeText(txt, DBLSIZE)
  lcd.drawText((z.w - tw) / 2,
               (z.h - th) / 2 - 4,
               txt,
               DBLSIZE + COLOR_THEME_PRIMARY1)

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
