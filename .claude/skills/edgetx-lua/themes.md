# EdgeTX Color Themes

How to create and edit **color themes** for color-display EdgeTX radios. A theme defines the 13 OS color variables that drive the whole UI look & feel (TopBar, menus, buttons, sliders, popups, …).

> **A theme is NOT a Lua script.** Themes are plain data: a folder under `/THEMES/` with a `theme.yml` file plus images. There is no Lua code involved. The connection to Lua scripting is that the same color slots are exposed to scripts as the `COLOR_THEME_*` constants (see [§7](#7-relationship-to-lua-color_theme_-constants)) — so a script that draws with theme colors automatically follows whatever theme the user picked.

**Source of truth:** the official EdgeTX themes repo, `structure.md` and the `example/` theme — <https://github.com/EdgeTX/themes>. In-radio editor docs: <https://manual.edgetx.org/color-radios/radio-settings/themes>. This file is cross-checked against `structure.md` as of EdgeTX 2.12. If something contradicts the repo, the repo wins.

---

## 1. Folder structure

A theme is a single folder under `/THEMES/` on the SD card. **The folder name is the theme name** as far as discovery goes (the `name:` in `theme.yml` is what's shown in the UI). Required files:

| File              | Purpose                                                            |
| ----------------- | ----------------------------------------------------------------- |
| `theme.yml`       | Metadata + the 13 color values (the actual theme)                 |
| `logo.png`        | Logo/banner shown in the theme selector                           |
| `screenshot1.png` | Main screen with some common widgets                              |
| `screenshot2.png` | Model-selection screen (with ≥2 models)                           |
| `screenshot3.png` | Channel monitor or Radio/Hardware tab (shows the WARNING color)   |

Screenshots are PNG, typically **480×272**. Optional files:

| File                      | Purpose                                          | Radios (examples)             |
| ------------------------- | ------------------------------------------------ | ----------------------------- |
| `background_320x240.png`  | Background image for 320×240 displays            | PA01                          |
| `background_320x480.png`  | Background image for 320×480 displays            | EL18, NV14                    |
| `background_480x272.png`  | Background image for 480×272 displays            | TX16S, T16, X10, X12S         |
| `background_480x320.png`  | Background image for 480×320 displays            | PL18, PL18EV, T15             |
| `background_800x480.png`  | Background image for 800×480 displays            | TX16S MK3                     |
| `readme.txt`              | Any notes you want to ship with the theme        | —                             |

Match the background filename to the target radio's display resolution (see `hardware.md`).

---

## 2. `theme.yml` format

YAML, plain text, editable anywhere. The first line **must** be the `---` document marker.

```yml
---
summary:
  name: Theme name           # shown in EdgeTX UI
  author: Creator            # shown in EdgeTX UI
  info: Short description     # shown in EdgeTX UI
  # description: longer text  # optional, NOT shown in the UI
colors:
  PRIMARY1:   0xA0A0A0
  PRIMARY2:   0x202020
  PRIMARY3:   0x505050
  SECONDARY1: 0x808080
  SECONDARY2: 0x505050
  SECONDARY3: 0x303030
  FOCUS:      0xC0C0C0
  EDIT:       0xEEEEEE
  ACTIVE:     0xD0D0D0
  WARNING:    0x404040
  DISABLED:   0x808080
  QM_BG:      0x303030       # EdgeTX 2.12+
  QM_FG:      0xFFFFFF       # EdgeTX 2.12+
```

Color value formats (interchangeable):

| Notation                  | Example                       |
| ------------------------- | ----------------------------- |
| Hex                       | `PRIMARY1: 0xA0A0A0`          |
| `RGB()` decimal           | `SECONDARY1: RGB(128, 128, 128)` |
| `RGB()` hex components    | `SECONDARY1: RGB(0x80, 0x80, 0x80)` |

Colors are 24-bit RGB, `0xRRGGBB`, each component `00`–`FF`.

> EdgeTX stores colors internally as **RGB565** (5/6/5 bits). The low bits of your 8-bit-per-channel values get truncated on the radio, so two near-identical hex values can render identically. Don't rely on subtle 1–2 LSB differences.

---

## 3. The 13 color variables

| Variable     | Since   | Role (short)                              |
| ------------ | ------- | ----------------------------------------- |
| `PRIMARY1`   | —       | Foreground text on dark/default surfaces  |
| `PRIMARY2`   | —       | Bars/icons foreground + editable-field bg |
| `PRIMARY3`   | —       | Secondary/inactive foreground accents     |
| `SECONDARY1` | —       | Bar backgrounds + slider/trim paths       |
| `SECONDARY2` | —       | Label / button backgrounds                |
| `SECONDARY3` | —       | Main screen + popup background            |
| `FOCUS`      | —       | Highlight for the focused/selected item   |
| `EDIT`       | —       | Field background while actively editing   |
| `ACTIVE`     | —       | "On/active" state background              |
| `WARNING`    | —       | Warning text color                        |
| `DISABLED`   | —       | Greyed-out / disabled elements            |
| `QM_BG`      | 2.12+   | Quick Menu background                     |
| `QM_FG`      | 2.12+   | Quick Menu foreground                     |

Targeting a radio on 2.11 or earlier? `QM_BG`/`QM_FG` are simply ignored — but include them anyway for forward compatibility.

---

## 4. Color → UI element map (authoritative)

This is the exact mapping from `structure.md`. Use it to reason about contrast (which slot is a background, which is the text drawn on top of it).

```
PRIMARY1
  Label text
  Button text (not focused)

PRIMARY2
  ETX Logo icon
  TopBar icons
  TopBar text
  TopBar tab name text
  BottomBar text
  Editable field background
  Editable field text (editing)
  Button text (focused)
  PopUp selectable field background
  Trim knob
  Slider knob

PRIMARY3
  Scroll marker
  Inactive part of TopBar icons

SECONDARY1
  TopBar background
  BottomBar background
  Trim knob path
  Trim knob shadow
  Slider path
  Slider knob shadow

SECONDARY2
  Label background
  Button background

SECONDARY3
  Main screen background
  PopUp background

FOCUS
  ETX Logo background
  TopBar icon background (selected)
  Label background (focused)
  Editable field background (focused)
  Trim knob
  Slider knob

EDIT
  Editable field background (editing)

ACTIVE
  Button background (active)
  Editable field background (variable active)

WARNING
  Label text (warning)

DISABLED
  Disabled elements
```

```
QM_BG          Quick Menu background          (2.12+)
QM_FG          Quick Menu foreground          (2.12+)
```

---

## 5. Contrast pairs that must stay legible

A theme breaks visually when a foreground slot has too little contrast with the background it lands on. The map above produces these **must-be-readable** pairings — check each one:

| Foreground            | Background          | Where it shows                         |
| --------------------- | ------------------- | -------------------------------------- |
| `PRIMARY1`            | `SECONDARY3`        | Label text on main screen / popups     |
| `PRIMARY1`            | `SECONDARY2`        | Button text (not focused) on buttons   |
| `PRIMARY2`            | `SECONDARY1`        | TopBar/BottomBar text & icons on bars  |
| `PRIMARY1` (text)     | `FOCUS`             | Focused label / focused editable field |
| `PRIMARY2` (text)     | `EDIT`              | Field text while editing               |
| `WARNING`             | `SECONDARY2`/`SECONDARY3` | Warning labels                   |
| `PRIMARY3`            | `SECONDARY1`        | Inactive TopBar icon parts             |
| `QM_FG`               | `QM_BG`             | Quick Menu (2.12+)                     |

Practical rules of thumb:
- **`PRIMARY*` are foregrounds, `SECONDARY*` are backgrounds.** Keep the two groups on opposite ends of the brightness range (light text + dark surfaces, or vice-versa).
- **`PRIMARY2` has a dual role** — it's a foreground (logo/bar icons & text) *and* the editable-field background. Pick it so it both contrasts against `SECONDARY1` (bars) and works as a field fill; in practice it's the dark base color, often equal to `SECONDARY3`.
- `FOCUS`, `EDIT`, `ACTIVE` are highlight backgrounds — make them clearly distinct from `SECONDARY2`/`SECONDARY3` *and* still readable under `PRIMARY1`/`PRIMARY2` text.
- `WARNING` is text-only — pick something that pops against the label/screen backgrounds (typically red).
- `DISABLED` should read as "muted" — a mid-grey between fg and bg.
- It's common and fine to set `SECONDARY3 == PRIMARY2` (the dark base color used both as screen bg and as bar/icon foreground), as the stock themes do.

---

## 6. Creating a theme

### Option A — edit `theme.yml` directly (fastest for full control)
1. Start from `templates/theme.yml` in this skill (a fully-commented 13-color file), or duplicate an existing theme folder under `/THEMES/` (e.g. copy the stock `EdgeTX` theme) so you inherit valid images.
2. Create/rename the folder under `/THEMES/`.
3. Edit `theme.yml`: set `summary.name`/`author`/`info`, then tune the 13 colors.
4. Walk the [contrast pairs](#5-contrast-pairs-that-must-stay-legible).
5. Copy to the radio's SD card `/THEMES/`, then on the radio: **Theme screen → long-press your theme → Set Active**.
6. Replace the screenshots/logo to match (optional but expected if you'll share it).

### Option B — on the radio (no PC needed)
1. **Theme screen → long-press a theme → Duplicate** (or build from scratch via the editor).
2. Open the editor: pick a color variable from the left sidebar, adjust with the **RGB or HSV** sliders (toggle in the upper-right).
3. Press the theme logo to go back to the variable list; press it again to **save & exit**.
4. Use **Details** to set name/author/description.
5. The radio writes these changes back into the theme's `theme.yml`, so you can later pull it off the SD card to share.

To share/submit: the EdgeTX themes repo (`THEMES/<YourTheme>/`) expects the full required file set from [§1](#1-folder-structure).

---

## 7. Relationship to Lua `COLOR_THEME_*` constants

In Lua scripts the active theme's colors are available as constants, so script UIs match the user's theme automatically:

| theme.yml slot | Lua constant                |
| -------------- | --------------------------- |
| `PRIMARY1`     | `COLOR_THEME_PRIMARY1`      |
| `PRIMARY2`     | `COLOR_THEME_PRIMARY2`      |
| `PRIMARY3`     | `COLOR_THEME_PRIMARY3`      |
| `SECONDARY1`   | `COLOR_THEME_SECONDARY1`    |
| `SECONDARY2`   | `COLOR_THEME_SECONDARY2`    |
| `SECONDARY3`   | `COLOR_THEME_SECONDARY3`    |
| `FOCUS`        | `COLOR_THEME_FOCUS`         |
| `EDIT`         | `COLOR_THEME_EDIT`          |
| `ACTIVE`       | `COLOR_THEME_ACTIVE`        |
| `WARNING`      | `COLOR_THEME_WARNING`       |
| `DISABLED`     | `COLOR_THEME_DISABLED`      |

These are **indexed** colors: change the theme and every script using them re-colors instantly. There is no Lua constant for `QM_BG`/`QM_FG` — those are OS-only. Prefer `COLOR_THEME_*` over the fixed legacy colors (BLACK/WHITE/RED…) so scripts respect the user's theme. See `api-reference.md` → Theme colors.

---

## 8. Pitfalls

- **Folder must be directly under `/THEMES/`**, one folder per theme. No nesting.
- **First line of `theme.yml` must be `---`.** A missing document marker or bad indentation makes the radio skip the theme silently.
- **YAML indentation matters** — use spaces, not tabs; `name`/`author`/`info` are nested under `summary:`, the colors under `colors:`.
- **`description:` is not shown in the UI** — use `info:` for the user-visible blurb.
- **RGB565 truncation** (see [§2](#2-themeyml-format)) — design with real radio rendering in mind, not pixel-perfect 24-bit.
- **Don't make `DISABLED` equal to `PRIMARY1`** — disabled items would look enabled.
- **WARNING is text-only.** Setting it to a background-like color does nothing useful; it never paints a fill.
- **Test on the actual display family.** A theme tuned on a bright 800×480 panel can look washed-out or muddy on a dimmer 480×272 unit.
- Editing a theme **in the radio editor overwrites its `theme.yml`** — keep a backup if you hand-tuned the file.
