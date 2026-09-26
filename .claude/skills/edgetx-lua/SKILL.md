---
name: edgetx-lua
description: Use when writing, reviewing, or debugging EdgeTX Lua scripts (widgets, telemetry, mix, function, or tool scripts) or when creating/editing EdgeTX color themes (theme.yml, the 13 OS color variables). Provides API reference, script lifecycle structure, hardware specs for color radios (TX16S, TX16S Mk III, TX15, Horus X10/X12) and notes on B/W radios (Boxer, Pocket, TX12, T-Pro), code templates, theme structure and color-to-UI-element mapping, common pitfalls, and debugging tips so EdgeTX-specific information does not need to be researched on the web each time.
---

# EdgeTX Lua Scripting

This skill is a reference base for programming Lua scripts that run on radios with EdgeTX firmware (RC transmitters like FrSky Horus, RadioMaster TX16S/TX15/Boxer/TX12, Jumper, etc.).

## When to use this skill

Invoke this skill whenever the user works with:
- `.lua` files in folders `SCRIPTS/`, `WIDGETS/`, `SCRIPTS/TELEMETRY/`, `SCRIPTS/MIXES/`, `SCRIPTS/FUNCTIONS/`, `SCRIPTS/TOOLS/`
- EdgeTX API calls (`lcd.*`, `getValue`, `model.*`, `getFieldInfo`, telemetry sensors)
- Discussions about EdgeTX widgets, telemetry screens, mixer scripts, or radio tools
- Migration questions involving OpenTX/EdgeTX scripts
- Creating or editing **color themes** (`/THEMES/`, `theme.yml`, the 13 color variables)

## Quick decision guide

| User wants to build...               | Read first                                |
| ------------------------------------ | ----------------------------------------- |
| A widget on the main/telemetry view  | `script-types.md` → Widget, `templates/widget.lua` |
| A fullscreen page on a color radio   | `script-types.md` → Widget (fullscreen / one-zone layout), `templates/widget.lua` |
| A telemetry page on a B/W radio      | `script-types.md` → Telemetry, `templates/telemetry.lua` (B/W only) |
| A custom mixer                       | `script-types.md` → Mix, `templates/mix.lua` |
| A background/special function script | `script-types.md` → Function, `templates/function.lua` |
| A one-shot tool in the TOOLS menu    | `script-types.md` → Tool, `templates/tool.lua` |
| Anything that draws on screen        | `api-reference.md` → LCD section + `hardware.md` |
| Anything reading sticks/switches/sensors | `api-reference.md` → Input/Events     |
| Anything reading/writing model setup | `api-reference.md` → Model API           |
| Storing data on SD card, listing, deleting or renaming files (`dir`, `fstat`, `del`, `rename`) | `api-reference.md` → File/IO |
| A color theme (`theme.yml`)          | `themes.md`                              |
| A recurring building block (e.g. link up/lost detection) | `patterns.md` |

## File index

- **`script-types.md`**: Script categories, file locations on SD card, required return tables, lifecycle functions (`init`, `run`, `background`, `create`, `update`, `refresh`), and entry points per script type.
- **`api-reference.md`**: EdgeTX Lua API by category: LCD/drawing, colors/fonts/flags, input sources (`getValue`), events (key + touch), telemetry/sensors, model API (`model.*`), file IO and paths.
- **`hardware.md`**: Display resolutions, capabilities, and color-vs-monochrome differences for color radios (TX16S, Mk III, TX15, Horus), UI scaling (`lvgl.LCD_SCALE`), CPUs, and which radios are B/W.
- **`pitfalls.md`**: CPU and memory limits per script type, Lua 5.3 subset restrictions (no `os`, no `package`, no string methods), value-range traps, font/BOLD traps, OpenTX→EdgeTX gotchas worth knowing even if migration is not the focus.
- **`debugging.md`**: `print()` (simulator only), VS Code Dev Kit and Companion simulators, runtime errors, common "script halted" causes, and how to verify before flashing to the radio.
- **`patterns.md`**: Canonical, source-verified implementations of recurring building blocks (link detection, throttled sensor existence, ...) so every project implements them the same way.
- **`themes.md`**: Color theme creation: `/THEMES/` folder layout, `theme.yml` format, the 13 OS color variables, the source-verified color→UI-element map (simulator-confirmed), contrast pairs to keep legible, the in-radio theme editor workflow, and how the slots map to Lua `COLOR_THEME_*` constants.
- **`templates/*.lua`**: Minimal working skeletons for each script type. Copy-paste starting points.
- **`templates/theme.yml`**: Commented starting point for a color theme (all 13 variables with their roles inline).

## How to use the references

1. **Identify the script type** from the user's request and load `script-types.md` if unsure.
2. **Open the matching template** under `templates/` as the starting structure.
3. **Look up specific API calls** in `api-reference.md` before inventing function signatures: EdgeTX has many small differences from stock Lua.
4. **Check `hardware.md`** before hard-coding pixel coordinates, colors, or assuming touch is available.
5. **Cross-check `pitfalls.md`** when a script behaves oddly or runs slowly: many EdgeTX "bugs" are documented constraints.

## Important rules when writing EdgeTX Lua

- **Return the correct table.** Every script file must end with `return { ... }` containing exactly the functions EdgeTX expects for that script type. Wrong keys = script silently does nothing or halts.
- **Never block.** No `sleep`, no busy loops. Widgets get 20,000 Lua instructions per call before a "CPU limit" error; split heavy work across calls; see `pitfalls.md` → Performance limits.
- **No standard Lua modules.** `os`, `io.popen`, `package`, `require` for arbitrary modules, `debug` are unavailable or restricted. Use `loadScript()` for splitting code, not `require`.
- **LCD state is per-frame on color radios.** Always redraw fully in `refresh`/`run`; do not assume previous draw persists.
- **Coordinates depend on the radio.** Always compute from `LCD_W` / `LCD_H` (and from widget zone `width`/`height` for widgets) instead of hard-coding.
- **Model writes are saved automatically.** `model.set*` marks the model dirty and EdgeTX writes it after a few seconds; don't call setters every frame; see `api-reference.md` → Saving.

## Source of truth

When sources disagree, this order wins:

1. **EdgeTX source code** (`github.com/EdgeTX/edgetx`, `radio/src/lua/` and friends). Currently checked against **v2.12.4**.
2. **Observed behaviour** on a radio or in the simulator.
3. **The official Lua Reference Guide** (<https://luadoc.edgetx.org/>, baseline 2.10, a local copy lives in this repo under `lua-reference-guide/`). Mostly accurate, but lags behind: e.g. it still states the 10-char / no-space limit for widget option names (gone since 2.11) and the legacy "add `zone.x`/`zone.y`" rule for widgets (modern EdgeTX draws zone-local; see `script-types.md` → Widget).

Statements in this skill that carry a source note like "(`file.cpp`, v2.12.4)" were verified against the source; statements without one are unverified. If you find a contradiction, tell the user so the skill can be corrected.
