# Reusable Patterns

Canonical implementations of small building blocks that recur across EdgeTX scripts. Use them as written so every project behaves the same; adapt names, not logic. Each pattern states its purpose, the code, why it works (with source), a host-test stub and known edge cases. Entries without a source note are unverified (see `SKILL.md` → Source of truth).

## Link detection

**Purpose:** tell "telemetry link up" from "link lost", for any telemetry system, without depending on a sensor name.

```lua
-- True while EdgeTX receives telemetry (any protocol).
local function linkUp()
  return getRSSI() ~= 0
end

-- Debounced loss: true once the link has been down for `grace` (same unit as `now`).
-- state.linkLostSince is nil while the link is up.
local function linkLost(state, up, now, grace)
  if up then
    state.linkLostSince = nil
    return false
  end
  state.linkLostSince = state.linkLostSince or now
  return now - state.linkLostSince >= grace
end
```

Usage: read `linkUp()` once per tick where the other sensors are read (snapshot), pass the result to `linkLost` in the evaluation. `linkLost` stays pure (no API call), so the state machine can be tested and simulated with a scripted `up`. The caller picks the time unit: `getTime()` ticks with `grace = 150`, or milliseconds with `grace = 1500`. The grace counts from the first tick that sees the link down (not from the last tick that saw it up), so in host tests step once without link before the long step.

```lua
local up   = linkUp()                            -- in the read step
local lost = linkLost(state, up, now, 1500)      -- in the evaluate step (now in ms)
if not up then
  if lost then --[[ end flight / reset warnings ]] end
  return                                          -- offline: skip the evaluation
end
```

**Why:**
- `getRSSI()` returns `min(99, TELEMETRY_RSSI())` while telemetry is streaming, else `0` (`lua/api_general.cpp`, v2.12.4).
- Every telemetry protocol sets that value and the "streaming" flag on reception; the flag drops 1 s after the last packet (`TELEMETRY_TIMEOUT10ms`, `telemetry/telemetry.cpp`; per protocol in `telemetry/crossfire.cpp`, `ghost.cpp`, `frsky_d.cpp`, `frsky_sport.cpp`, `flysky_ibus.cpp`, `flysky_ibus2.cpp`, `flysky_nv14.cpp`, `spektrum.cpp`, `hott.cpp`, `hitec.cpp`, `mlink.cpp`, v2.12.4). See `api-reference.md` → `getRSSI()` for what the value means per system.
- `getValue("RQly") > 0` and `getSourceValue` with `isCurrent` key off the same flag, so they detect the same thing but need a sensor name that differs per system and can be renamed by the user.
- The grace period (1.5 s) is a project convention: long enough to bridge a single lost or zero-valued packet, short enough to react to a real loss.

**Only compare with `~= 0`.** The value means different things per system (CRSF: averaged RQly in %, FrSky: RSSI in dB, FlySky AFHDS2A: 100 minus error rate ...). Thresholds on it are not portable; read the system's own sensors for signal quality (e.g. `1RSS`/`RQly` on ELRS).

**Host-test stub** (models CRSF and FrSky from the test's sensor table):
```lua
getRSSI = function() return SOURCES.RQly or SOURCES.RSSI or 0 end
```

**Edge cases** (source as above, v2.12.4):
- FrSky D and Spektrum set the streaming flag regardless of the value; a packet carrying 0 makes `getRSSI()` 0 until the next packet. The grace period absorbs it.
- FlySky NV14 sets the flag on any sensor packet but the value only from the signal sensor: briefly 0 right after connecting.
- Hitec filters the value (10 % new, 90 % old) and halves it: can read 0 while packets arrive, at start-up or with a very weak signal.
- M-Link keeps the flag for 2 s instead of 1 s (slow LQI update rate).
- In the simulator EdgeTX skips the RSSI reset on streaming timeout (`#if !defined(SIMU)` in `telemetryInterrupt10ms`); `getRSSI()` still returns 0 there because it checks the streaming flag first.

## Sensor existence (throttled)

**Purpose:** know which telemetry sensors the model has (so the script can show "sensor missing" or `--` instead of computing on a fake 0), without calling `getFieldInfo` for every sensor on every tick.

```lua
-- getFieldInfo is nil for a sensor that was never discovered; getValue would give 0.
local function sensorExists(name)
  local ok, info = pcall(getFieldInfo, name)
  return ok and info ~= nil
end

-- Existence per sensor, re-checked at most every `interval` (same unit as `now`).
-- names = { key = "SensorName", ... }; returns the cached { key = true/false }.
local function sensorsPresent(state, names, now, interval)
  if state.sensorCheckAt == nil or now - state.sensorCheckAt >= interval then
    state.sensorCheckAt = now
    local has = {}
    for key, name in pairs(names) do has[key] = sensorExists(name) end
    state.sensorsPresent = has
  end
  return state.sensorsPresent
end

-- Value of a present sensor, nil when absent (display shows "--", not a fake 0).
local function readPresent(has, names, key)
  if not has[key] then return nil end
  local ok, v = pcall(getValue, names[key])
  if ok then return v end
  return nil
end
```

`readPresent` is only needed where optional sensors are read; leave it out of a script that has none.

**Call site** (same shape in every script):

```lua
-- 1. One names table, never built per tick: a module constant ...
M.SENSORS = { rqly = "RQly", tpwr = "TPWR", fm = "FM" }
local SENSOR_CHECK_MS = 1000

-- 2. ... read step: one sensorsPresent call per tick, then only `has`.
local has  = sensorsPresent(state, M.SENSORS, now, SENSOR_CHECK_MS)   -- now in ms
local rqlyMissing = not has.rqly
local tpwr = readPresent(has, M.SENSORS, "tpwr")                      -- nil -> "--"
```

When the user can remap sensor names (e.g. per model in a config), keep the names in one table on the state, replace that table only when a name actually changes, and set `state.sensorCheckAt = nil` at that moment so the next tick re-checks. Never pass a table literal (`{ a = x, b = y }`) to `sensorsPresent`: it would allocate a table on every tick.

**Why:**
- `getFieldInfo` returns no value for an unknown source (`api_general.cpp`, v2.12.4), while `getValue` returns 0 for it, indistinguishable from a real 0 (see `pitfalls.md` → API and value pitfalls).
- A sensor only appears after telemetry discovery, so existence can change while the script runs: check periodically, not once at load. Existence is model configuration and does not flicker with the link, so a cache of about 1 s is safe.
- The first call checks immediately (`sensorCheckAt == nil`), so a fresh state never starts with a wrong "missing".
- `pcall` guards against a raising call: a `nil` or table name (e.g. from a broken config) makes `getFieldInfo` throw (`luaL_checkstring` in `luaGetFieldInfo`, `api_general.cpp`, v2.12.4), so one bad sensor name cannot halt the script.

**Choosing `interval`:** use 1 s everywhere so all scripts react alike; it is independent of any config reload cadence.

**Host tests:** a test that adds or removes a sensor on a running state must either advance `now` past `interval` or reset `state.sensorCheckAt = nil`; otherwise it sees the cached result.

## Armed state from the flight-mode text (CRSF)

**Purpose:** know whether the model is armed, for flight-controller firmware that reports it in the CRSF flight-mode text (sensor `FM`): Betaflight, INAV, ArduPilot. Without a "disarmed" marker seen on the current link the state counts as unknown, so a firmware that never marks disarmed is not taken for "armed forever".

```lua
-- Disarmed marker in the FM text: Betaflight appends * ! ?, ArduPilot *,
-- INAV sends OK / WAIT / !ERR. "!FS!" (failsafe) is armed despite its "!".
local INAV_DISARMED = { OK = true, WAIT = true, ["!ERR"] = true }
local function fmDisarmed(fm)
  if fm == "!FS!" then return false end
  if INAV_DISARMED[fm] then return true end
  local last = string.sub(fm, -1)
  return last == "*" or last == "!" or last == "?"
end

-- armed, known. Known only once a disarmed marker was seen on this link
-- (state.disarmSeen): some setups never send one, and a text without a marker
-- alone proves nothing. Clear state.disarmSeen when the link is lost.
local function armedFromFM(state, fm)
  if type(fm) ~= "string" or fm == "" then return false, false end
  if fmDisarmed(fm) then
    state.disarmSeen = true
    return false, true
  end
  if not state.disarmSeen then return false, false end
  return true, true
end
```

Usage: call it once per tick with the `FM` value from the read step (`nil` when the sensor is missing, see "Sensor existence" above), in the evaluation, where `state` lives. Reset where the link loss is handled:

```lua
if lost then state.disarmSeen = nil end           -- next to linkLost (see "Link detection")
local armed, known = armedFromFM(state, snap.fm)
if not known then --[[ fall back: no arm edge, e.g. act on GPS fix / movement instead ]] end
```

An arm edge (disarmed → armed) needs `known` on both sides; a display "ARMED" shows `armed` (which is false while unknown).

**Why** (flight-controller sources, as researched for CRSF telemetry; EdgeTX passes the text unchanged, up to 16 characters, `telemetry/crossfire.cpp` `setTelemetryText`, v2.12.4):
- Betaflight (`src/main/telemetry/crsf.c` `crsfFrameFlightMode()`, master `744f95fa31`): mode name, plus `*` when disarmed and ready, `!` when arming is blocked, `?` when GPS Rescue is not available; armed without a marker; `!FS!` in failsafe.
- INAV (`src/main/telemetry/crsf.c` `crsfFrameFlightMode()`, master `4526102326`): never a marker; disarmed it sends `OK`, `WAIT` (no GPS or home fix) or `!ERR` (arming blocked) instead of a mode name; `!FS!` in failsafe.
- ArduPilot (`libraries/AP_RCTelemetry/AP_CRSF_Telem.cpp` `calc_flight_mode()`, master): 4-character mode name plus `*` while disarmed **only** with `RC_OPTIONS` bit 12 (`CRSF_FM_DISARM_STAR`, 4096). The default (`RC_OPTIONS` = 32) never marks disarmed, which is why "armed" needs a marker seen first. In ExpressLRS MAVLink mode the TX module builds the text itself and always appends `*` while disarmed.
- No ArduPilot mode name equals an INAV disarmed text or ends in `!` or `?`, so one parser serves all three without knowing the firmware.

**Host tests:** feed a disarmed text before expecting `armed == true`; a fresh state with an armed text returns `false, false`.

**Edge cases:**
- Connecting to a model that is already armed (link regained in flight) stays unknown until the next disarm: no false arm edge.
- `!FS!` before any disarmed text is unknown, like every armed text.
