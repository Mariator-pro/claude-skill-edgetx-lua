---
name: edgetx-lua
description: Use when writing, reviewing, or debugging EdgeTX Lua scripts (widgets, telemetry, mix, function, or tool scripts). Provides API reference, script lifecycle structure, hardware specs for color radios (TX16S/X10/Horus/Boxer/T-Pro/TX12), code templates, common pitfalls, and debugging tips so EdgeTX-specific information does not need to be researched on the web each time.
---

# EdgeTX Lua Scripting

This skill is a reference base for programming Lua scripts that run on radios with EdgeTX firmware (RC transmitters like FrSky Horus, RadioMaster TX16S/Boxer/TX12/T-Pro, Jumper, etc.).

## When to use this skill

Invoke this skill whenever the user works with:
- `.lua` files in folders `SCRIPTS/`, `WIDGETS/`, `SCRIPTS/TELEMETRY/`, `SCRIPTS/MIXES/`, `SCRIPTS/FUNCTIONS/`, `SCRIPTS/TOOLS/`
- EdgeTX API calls (`lcd.*`, `getValue`, `model.*`, `getFieldInfo`, telemetry sensors)
- Discussions about EdgeTX widgets, telemetry screens, mixer scripts, or radio tools
- Migration questions involving OpenTX/EdgeTX scripts

## Quick decision guide

| User wants to build...               | Read first                                |
| ------------------------------------ | ----------------------------------------- |
| A widget on the main/telemetry view  | `script-types.md` → Widget, `templates/widget.lua` |
| A fullscreen telemetry page          | `script-types.md` → Telemetry, `templates/telemetry.lua` |
| A custom mixer                       | `script-types.md` → Mix, `templates/mix.lua` |
| A background/special function script | `script-types.md` → Function, `templates/function.lua` |
| A one-shot tool in the TOOLS menu    | `script-types.md` → Tool, `templates/tool.lua` |
| Anything that draws on screen        | `api-reference.md` → LCD section + `hardware.md` |
| Anything reading sticks/switches/sensors | `api-reference.md` → Input/Events     |
| Anything reading/writing model setup | `api-reference.md` → Model API           |
| Storing data on SD card              | `api-reference.md` → File/IO             |

## File index

- **`script-types.md`** — Script categories, file locations on SD card, required return tables, lifecycle functions (`init`, `run`, `background`, `create`, `update`, `refresh`), and entry points per script type.
- **`api-reference.md`** — EdgeTX Lua API by category: LCD/drawing, colors/fonts/flags, input sources (`getValue`), events (key + touch), telemetry/sensors, model API (`model.*`), file IO and paths.
- **`hardware.md`** — Display resolutions, capabilities, and color-vs-monochrome differences for radios the user cares about (Horus-class color/touch + compact radios).
- **`pitfalls.md`** — Performance/memory limits, Lua subset restrictions (no `os`, no `package`, etc.), refresh timing, save-after-write requirements, OpenTX→EdgeTX breaking gotchas worth knowing even if migration is not the focus.
- **`debugging.md`** — `print()` and the LCD console, EdgeTX Companion simulator, runtime errors, common "script halted" causes, and how to verify before flashing to the radio.
- **`templates/*.lua`** — Minimal working skeletons for each script type. Copy-paste starting points.

## How to use the references

1. **Identify the script type** from the user's request and load `script-types.md` if unsure.
2. **Open the matching template** under `templates/` as the starting structure.
3. **Look up specific API calls** in `api-reference.md` before inventing function signatures — EdgeTX has many small differences from stock Lua.
4. **Check `hardware.md`** before hard-coding pixel coordinates, colors, or assuming touch is available.
5. **Cross-check `pitfalls.md`** when a script behaves oddly or runs slowly — many EdgeTX "bugs" are documented constraints.

## Important rules when writing EdgeTX Lua

- **Return the correct table.** Every script file must end with `return { ... }` containing exactly the functions EdgeTX expects for that script type. Wrong keys = script silently does nothing or halts.
- **Never block.** No `sleep`, no busy loops. Each `run`/`refresh` call must return quickly (target < 30 ms on color radios). Heavy work must be split across frames.
- **No standard Lua modules.** `os`, `io.popen`, `package`, `require` for arbitrary modules, `debug` are unavailable or restricted. Use `loadScript()` for splitting code, not `require`.
- **LCD state is per-frame on color radios.** Always redraw fully in `refresh`/`run`; do not assume previous draw persists.
- **Coordinates depend on the radio.** Always compute from `LCD_W` / `LCD_H` (and from widget zone `width`/`height` for widgets) instead of hard-coding.
- **Save after model writes.** Most `model.*` setters require an explicit save or a context where EdgeTX saves automatically — see `api-reference.md`.

## Source of truth

The authoritative API is the official EdgeTX Lua Reference Guide at <https://luadoc.edgetx.org/>. The site currently documents **EdgeTX 2.10** as its baseline, with explicit notes about changes in 2.11 and 2.12 (e.g. widget option count, STRING length). The files in this skill have been **cross-checked against that guide** for the core APIs (script type return tables, filename limits, widget option limits, key/touch events, `getValue` behaviour, `lcd.drawText` signature, flag/color constants). If something is missing or behavior contradicts the guide, the guide wins — and the user should be told so the skill can be updated.

One known exception: for **widget drawing coordinates**, the guide (and `llms-full.txt`) still reflects the legacy OpenTX screen-origin model ("add `zone.x`/`zone.y`"). On modern EdgeTX, widgets actually draw in **zone-local** coordinates (`(0,0)` = zone corner, `zone.x`/`zone.y` ≈ `0`); see `script-types.md` → Widget.
