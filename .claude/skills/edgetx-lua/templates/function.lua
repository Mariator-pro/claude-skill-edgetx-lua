-- Minimal EdgeTX function script template.
-- Place as:  /SCRIPTS/FUNCTIONS/myfunc.lua
--   (filename without .lua must be 6 characters or less)
-- Assign via Model Setup -> Special Functions -> Lua Script,
-- or Radio Setup -> Global Functions for radio-wide.
--
-- Trigger semantics:
--   * run()        is called while the assigned switch / trigger is ON
--   * background() is called while it is OFF
--
-- This example plays a warning sound when battery (RxBt) drops below 7.0 V
-- (only active while the assigned switch is ON), throttled to once / 10 s.

local state = {
  lastBeep = 0,
  threshold = 70,     -- 7.0 V, expressed in 0.1 V units (our own scale; getValue("RxBt")
                      -- returns float volts, which run() converts below)
}

local function init()
  state.lastBeep = 0
end

local function run()
  -- No LCD here. Telemetry / sounds / model state only.
  local rxBatt = getValue("RxBt") or 0
  -- getValue returns a number; for VFAS/RxBt it is in volts as a float on
  -- EdgeTX (e.g. 7.4). Normalize:
  local v10 = math.floor(rxBatt * 10)   -- now in 0.1V units

  if v10 > 0 and v10 < state.threshold then
    local now = getTime()
    if now - state.lastBeep > 1000 then    -- 10 s = 1000 * 10 ms ticks
      playFile("/SOUNDS/en/lowbatt.wav")
      playHaptic(100, 0)
      state.lastBeep = now
    end
  end
end

local function background()
  -- Optional: same as run but called when trigger is not active.
end

return {
  init       = init,
  run        = run,
  background = background,
}
