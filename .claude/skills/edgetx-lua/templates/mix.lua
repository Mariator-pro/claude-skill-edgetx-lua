-- Minimal EdgeTX custom mixer script template.
-- Place as:  /SCRIPTS/MIXES/mymix.lua
--   (filename without .lua must be 6 characters or less)
-- Assign in Model Setup -> Custom Scripts.
--
-- This example takes a throttle SOURCE input and a "MinPct" VALUE input
-- (a percentage from -100..+100). It outputs the throttle clamped to
-- that minimum (useful for ESCs that need a non-zero idle).

local inputs = {
  { "Thr",    SOURCE },                 -- SOURCE: range -1024..+1024
  { "MinPct", VALUE, -100, 100, 0 },    -- VALUE: range must fit -128..+127
}

local outputs = { "ThrO" }   -- output names: max 4 chars (5 if the first char is +/-)

local function init()
  -- Called once when the model is loaded. Keep this very cheap.
end

local function run(thr, minPct)
  -- thr is in -1024..+1024 (SOURCE); minPct is in -100..+100 (VALUE).
  -- Convert minPct to the channel scale so we compare apples to apples.
  -- This function is called on EVERY mixer cycle. Be fast:
  --   * no LCD calls
  --   * no allocations
  --   * no string formatting
  local minScaled = minPct * 1024 / 100
  if thr < minScaled then
    return minScaled
  end
  return thr
end

return {
  init   = init,
  run    = run,
  input  = inputs,
  output = outputs,
}
