# EdgeTX Lua Skill for Claude Code

A [Claude Code](https://claude.com/claude-code) **Skill** that turns Claude into a knowledgeable assistant for writing Lua scripts on [EdgeTX](https://edgetx.org/) radios — so you don't have to re-explain the same API details, filename limits, and hardware quirks every time you start a new script.

## What is this?

A Claude Code Skill is a small bundle of documentation that Claude loads automatically when the topic comes up. This skill packages a condensed reference for EdgeTX Lua development:

- **Script types and lifecycles** — Widget, Telemetry, Mix, Function, and Tool scripts
- **API reference** — LCD/drawing, input/events/touch, telemetry, `model.*`, file I/O
- **Hardware specs** — color/touch radios (TX16S Mk I–III, X10, Horus) and compact color (Boxer, Pocket, T-Pro v2)
- **Common pitfalls** — silent-load failures, filename limits, value-range gotchas, the Lua subset's restrictions
- **Debugging tips** — Companion simulator workflow, `print()` console, `pcall` patterns
- **Templates** — minimal working boilerplates for all five script types

When you ask Claude something like *"build me a widget that shows RSSI as a bar"* or *"why does my telemetry script not load on the radio?"*, Claude will read the relevant pieces of the skill and answer with EdgeTX-specific knowledge instead of generic Lua advice.

## Why this skill exists

EdgeTX has small but high-friction quirks that are easy to forget:

- Telemetry / Mix / Function scripts whose filename (without `.lua`) is longer than 6 characters are silently ignored.
- Mix-script `VALUE` inputs are limited to `-128..+127`, not the channel range `±1024`.
- `touchState` does not contain an `event` field — the event is a separate function argument.
- Widget option limits changed between EdgeTX 2.10 (5 options, STRING ≤ 8 chars) and 2.11+ (10 options, STRING ≤ 12 chars).
- `os`, `require`, `io.popen`, `debug`, and coroutines are all unavailable.

This skill captures these details so they don't have to be re-researched every session.

## Installation

### Option A — Project-level (versioned with your code)

Drop the `.claude/skills/edgetx-lua/` directory anywhere inside a project where you write EdgeTX Lua:

```bash
# from the root of your EdgeTX scripts project
mkdir -p .claude/skills
cp -r path/to/this/repo/.claude/skills/edgetx-lua .claude/skills/
```

The skill is then available whenever Claude Code is run inside that project.

### Option B — User-level (global, available in every project)

```bash
mkdir -p ~/.claude/skills
cp -r path/to/this/repo/.claude/skills/edgetx-lua ~/.claude/skills/
```

The skill is now available to Claude Code regardless of which directory you start from.

## Usage

Once installed, the skill is invoked automatically. Triggers include:

- Working with `.lua` files inside `SCRIPTS/`, `WIDGETS/`, `SCRIPTS/TELEMETRY/`, `SCRIPTS/MIXES/`, `SCRIPTS/FUNCTIONS/`, `SCRIPTS/TOOLS/`
- Mentioning EdgeTX API calls (`lcd.*`, `getValue`, `model.*`, telemetry sensors)
- Asking about widgets, telemetry pages, mixer scripts, custom function scripts, or radio tools

Example prompts that activate the skill:

```
"Write me a widget that shows RxBatt as a vertical bar, color thresholds at 7.0V and 7.4V."
"Why does my telemetry script work in the simulator but not on the radio?"
"Convert this OpenTX widget to EdgeTX 2.11."
"What's the right way to persist tool state across reboots?"
```

You don't have to mention the skill by name — Claude reads `SKILL.md` and pulls in the matching reference files.

## What's covered

| Area                          | Coverage | File                       |
| ----------------------------- | -------- | -------------------------- |
| Script types & lifecycles     | full     | `script-types.md`          |
| LCD / drawing API             | full     | `api-reference.md`         |
| Input / events / touch        | full     | `api-reference.md`         |
| Telemetry & sensor reading    | full     | `api-reference.md`         |
| `model.*` API                 | core     | `api-reference.md`         |
| File I/O                      | core     | `api-reference.md`         |
| Hardware specs                | TX16S I/II/III, X10, Horus, Boxer, Pocket, T-Pro v2 | `hardware.md` |
| Performance limits / Lua subset | full   | `pitfalls.md`              |
| Debugging workflow            | full     | `debugging.md`             |
| Templates                     | all five script types | `templates/*.lua` |

### EdgeTX versions

The skill is verified against the official [EdgeTX Lua Reference Guide](https://luadoc.edgetx.org/), which documents **EdgeTX 2.10** as its baseline with explicit notes about changes in 2.11 and 2.12. Version-specific differences (like the widget option count and STRING length) are called out where they matter.

## Project structure

```
.claude/skills/edgetx-lua/
├── SKILL.md              Entry point + index of subfiles
├── script-types.md       Widget / Telemetry / Mix / Function / Tool lifecycles
├── api-reference.md      LCD, input/events, telemetry, model.*, IO
├── hardware.md           Display sizes & capabilities per radio
├── pitfalls.md           Silent failures, value ranges, Lua subset
├── debugging.md          Simulator workflow, print(), pcall, checklist
└── templates/
    ├── widget.lua
    ├── telemetry.lua
    ├── mix.lua
    ├── function.lua
    └── tool.lua
```

## Source & verification

All function signatures, constants, and limits are cross-checked against <https://luadoc.edgetx.org/>. Where the documentation is ambiguous (e.g. the widget `zone` table's exact fields, the precise list of supported `EVT_VIRTUAL_*` constants), the skill follows current real-world EdgeTX behaviour and flags the ambiguity in `SKILL.md` or the relevant file.

## Limitations

- The skill is **not** a full clone of the EdgeTX Lua reference. It covers the parts most relevant to authoring custom scripts. For exotic APIs (e.g. SBUS frame manipulation, deep Crossfire telemetry), defer to the official docs.
- Hardware coverage focuses on color radios. Black-and-white compact radios (TX12 Mk I, T-Pro, X-Lite, etc.) are mentioned but not deeply covered.
- The skill reflects the EdgeTX feature set documented at <https://luadoc.edgetx.org/> at the time of last update. Newer EdgeTX releases may add APIs that are not yet in this skill — PRs welcome.

## Contributing

Spotted an inaccuracy? Found an EdgeTX API the skill doesn't cover? Adapted the templates for a specific radio? Please open an issue or PR.

Practical tip: the cleanest way to extend the skill is to:
1. Run Claude Code with this skill installed.
2. Ask it to do something that exposes a gap or wrong answer.
3. Open the relevant file under `.claude/skills/edgetx-lua/`, fix it, commit.
4. Re-run the same prompt — the gap should now be closed.

## Related

- [EdgeTX](https://edgetx.org/) — the firmware this skill targets
- [EdgeTX Lua Reference Guide](https://luadoc.edgetx.org/) — official API documentation
- [Claude Code](https://claude.com/claude-code) — the CLI this skill runs in
- [Claude Code Skills docs](https://docs.claude.com/en/docs/claude-code/skills) — how skills work

## License

License: **TBD** — to be decided before first publication.

> Note: EdgeTX itself is licensed under GPLv3. If this skill incorporates substantial verbatim excerpts from EdgeTX documentation (currently it does not — content is paraphrased), a compatible license may be appropriate.
