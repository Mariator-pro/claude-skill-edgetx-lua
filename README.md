# claude-skill-edgetx-lua

A [Claude Code](https://claude.com/claude-code) Skill that turns Claude into a knowledgeable assistant for writing Lua scripts on [EdgeTX](https://edgetx.org/) radios, so you don't have to re-explain the same API details, filename limits, and hardware quirks every time you start a new script.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![EdgeTX](https://img.shields.io/badge/EdgeTX-%E2%89%A5%202.10-brightgreen)](https://edgetx.org)
[![Claude Code](https://img.shields.io/badge/Claude_Code-Skill-orange)](https://claude.com/claude-code)
[![GitHub issues](https://img.shields.io/github/issues/Mariator-pro/claude-skill-edgetx-lua)](../../issues)
[![GitHub last commit](https://img.shields.io/github/last-commit/Mariator-pro/claude-skill-edgetx-lua)](../../commits/main)

---

## 📚 Table of Contents

- [🎯 What is it for?](#-what-is-it-for)
- [📥 Installation](#-installation)
- [✨ Usage](#-usage)
- [📁 Project structure](#-project-structure)
- [🤝 Contributing](#-contributing)
- [📄 License](#-license)

---

## 🎯 What is it for?

A Claude Code Skill is a small bundle of documentation that Claude loads automatically when the topic comes up. This skill packages a condensed reference for EdgeTX Lua development:

- **Script types and lifecycles**: Widget, Telemetry, Mix, Function, and Tool scripts
- **API reference**: LCD/drawing, input/events/touch, telemetry, `model.*`, file I/O
- **Hardware specs**: color/touch radios (TX16S Mk I–III, X10, Horus) and compact color (Boxer, Pocket, T-Pro v2)
- **Common pitfalls**: silent-load failures, filename limits, value-range gotchas, the Lua subset's restrictions
- **Debugging tips**: Companion simulator workflow, `print()` console, `pcall` patterns
- **Color themes**: `theme.yml` structure, the 13 OS color variables, the authoritative color→UI-element map, and how those slots map to the Lua `COLOR_THEME_*` constants
- **Templates**: minimal working boilerplates for all five script types, plus a commented `theme.yml`

When you ask Claude something like *"build me a widget that shows RSSI as a bar"* or *"why does my telemetry script not load on the radio?"*, Claude will read the relevant pieces of the skill and answer with EdgeTX-specific knowledge instead of generic Lua advice.

Lua content is verified against the official [EdgeTX Lua Reference Guide](https://luadoc.edgetx.org/); the theme reference is verified against the [EdgeTX themes repo](https://github.com/EdgeTX/themes) (`structure.md`) and the [EdgeTX User Manual](https://manual.edgetx.org/color-radios/radio-settings/themes).

---

## 📥 Installation

### Option A: Project-level (versioned with your code)

Drop the `.claude/skills/edgetx-lua/` directory anywhere inside a project where you write EdgeTX Lua:

```bash
# from the root of your EdgeTX scripts project
mkdir -p .claude/skills
cp -r path/to/this/repo/.claude/skills/edgetx-lua .claude/skills/
```

The skill is then available whenever Claude Code is run inside that project.

### Option B: User-level (global, available in every project)

```bash
mkdir -p ~/.claude/skills
cp -r path/to/this/repo/.claude/skills/edgetx-lua ~/.claude/skills/
```

The skill is now available to Claude Code regardless of which directory you start from.

---

## ✨ Usage

Once installed, the skill is invoked automatically. Triggers include:

- Working with `.lua` files inside `SCRIPTS/`, `WIDGETS/`, `SCRIPTS/TELEMETRY/`, `SCRIPTS/MIXES/`, `SCRIPTS/FUNCTIONS/`, `SCRIPTS/TOOLS/`
- Mentioning EdgeTX API calls (`lcd.*`, `getValue`, `model.*`, telemetry sensors)
- Asking about widgets, telemetry pages, mixer scripts, custom function scripts, or radio tools
- Creating or editing color themes (`/THEMES/`, `theme.yml`, the 13 color variables)

Example prompts that activate the skill:

```
"Write me a widget that shows RxBatt as a vertical bar, color thresholds at 7.0V and 7.4V."
"Why does my telemetry script work in the simulator but not on the radio?"
"Build me a dark EdgeTX theme with an orange accent and tell me which colors I set."
```

---

## 📁 Project structure

```
.claude/skills/edgetx-lua/
├── SKILL.md              Entry point + index of subfiles
├── script-types.md       Widget / Telemetry / Mix / Function / Tool lifecycles
├── api-reference.md      LCD, input/events, telemetry, model.*, IO
├── hardware.md           Display sizes & capabilities per radio
├── pitfalls.md           Silent failures, value ranges, Lua subset
├── debugging.md          Simulator workflow, print(), pcall, checklist
├── themes.md             theme.yml structure, 13 color variables, color→UI map
└── templates/
    ├── widget.lua
    ├── telemetry.lua
    ├── mix.lua
    ├── function.lua
    ├── tool.lua
    └── theme.yml         Commented color-theme starting point
```

---

## 🤝 Contributing

Spotted an inaccuracy, missing an EdgeTX API, or want a new radio added to the hardware reference? Please [open an issue](../../issues) on GitHub. Pull requests are welcome too.

---

## 📄 License

Released under the [MIT License](LICENSE).

