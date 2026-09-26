# EdgeTX Color Themes

How to create and edit **color themes** for color-display EdgeTX radios. A theme defines the 13 OS color variables that drive the whole UI look & feel (TopBar, menus, buttons, sliders, popups, …).

> **A theme is NOT a Lua script.** Themes are plain data: a folder under `/THEMES/` with a `theme.yml` file plus images. There is no Lua code involved. The connection to Lua scripting is that the same color slots are exposed to scripts as the `COLOR_THEME_*` constants (see [§7](#7-relationship-to-lua-color_theme_-constants)): so a script that draws with theme colors automatically follows whatever theme the user picked.

**Source of truth:** the EdgeTX source code, v2.12.4. File format, color names, limits and file lookup: `gui/colorlcd/themes/theme_manager.cpp`. The color → UI-element map in §4: the LVGL styles under `radio/src/gui/colorlcd/`, confirmed in the TX16S MK3 simulator with a diagnostic theme (see [§9](#9-verifying-the-map-diagnostic-theme)). Folder layout and required files: the official themes repo (`structure.md`, <https://github.com/EdgeTX/themes>). Its color assignment list is **outdated and partly wrong**; do not use it. In-radio editor docs: <https://manual.edgetx.org/color-radios/radio-settings/themes>. On conflicts the source code wins (see `SKILL.md` → Source of truth).

---

## 1. Folder structure

A theme is a single folder under `/THEMES/` on the SD card. **The folder name is the theme name** as far as discovery goes (the `name:` in `theme.yml` is what's shown in the UI).

**The radio only needs `theme.yml`**: it scans every folder under `/THEMES/` for that file (`theme_manager.cpp`, v2.12.4). Logo and screenshots are only shown in the theme selector; they are required for submitting to the official themes repo:

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
| `background.png`          | Fallback when no `background_<W>x<H>.png` matches the display (`theme_manager.cpp`) | any |
| `readme.txt`              | Any notes you want to ship with the theme        | -                             |

Match the background filename to the target radio's display resolution (see `hardware.md`).

---

## 2. `theme.yml` format

YAML, plain text, editable anywhere. Start with the `---` document marker: older EdgeTX versions need it, 2.12 also reads files without it, and the radio's editor always writes it (`theme_manager.cpp`, v2.12.4).

```yml
---
summary:
  name: Theme name           # shown in EdgeTX UI
  author: Creator            # shown in EdgeTX UI
  info: Short description     # shown in EdgeTX UI
  # description: longer text  # optional, NOT read at all
# limits (longer is cut): name 26, author 50, info 255 chars (dataconstants.h / theme_manager.h)
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

Short roles, derived from the source map in [§4](#4-color--ui-element-map-source-verified):

| Variable     | Since   | Role (short)                                                             |
| ------------ | ------- | ------------------------------------------------------------------------ |
| `PRIMARY1`   | -       | Label text; list item text; text on ACTIVE (checked) buttons              |
| `PRIMARY2`   | -       | **Control background** (buttons, fields, list items); text on bars and on FOCUS/EDIT fills |
| `PRIMARY3`   | -       | Inactive parts of TopBar status icons (RSSI bars, USB, GPS)               |
| `SECONDARY1` | -       | TopBar/header/footer background; **control text**; slider/trim paths; toggle knob |
| `SECONDARY2` | -       | Control borders; list separators                                         |
| `SECONDARY3` | -       | Page, dialog, popup and keyboard background                              |
| `FOCUS`      | -       | Focus **border/outline** of controls; **fill** of the selected list entry; logo background; slider knob |
| `EDIT`       | -       | Field background while editing                                           |
| `ACTIVE`     | -       | Checked/on state background (buttons, toggles, keyboard keys)            |
| `WARNING`    | -       | Warning text and icons; **also a fill** (full-screen alert, timer widget) |
| `DISABLED`   | -       | Only a few specific texts (see §4); **not** used for disabled controls    |
| `QM_BG`      | 2.12+   | Quick Menu background                                                    |
| `QM_FG`      | 2.12+   | Quick Menu foreground                                                    |

Targeting a radio on 2.11 or earlier? `QM_BG`/`QM_FG` are simply ignored: but include them anyway for forward compatibility.

---

## 4. Color → UI element map (source-verified)

> **`structure.md` in the themes repo is wrong in several places.** It says buttons use `SECONDARY2` background with `PRIMARY1` text, that `FOCUS` fills focused fields, that `DISABLED` colors disabled elements and that `PRIMARY3` is the scroll marker. The EdgeTX source (v2.12.4) and the simulator show otherwise. This section follows the source; do not copy `structure.md` back in.

Markers: **[src]** = read in the EdgeTX source, v2.12.4 (paths under `radio/src/gui/colorlcd/`). **[sim]** = additionally confirmed in the TX16S MK3 simulator with the diagnostic theme from [§9](#9-verifying-the-map-diagnostic-theme).

### Controls (buttons, text/number fields, choice fields, toggles)

All standard controls share `etx_std_ctrl_colors()` / `etx_std_settings()` (`libui/etx_lv_theme.cpp:571-595`).

| State        | Background   | Text         | Border/outline | Notes |
| ------------ | ------------ | ------------ | -------------- | ----- |
| Normal       | `PRIMARY2`   | `SECONDARY1` | `SECONDARY2`   | [src] [sim] |
| Focused      | `PRIMARY2` (unchanged) | `SECONDARY1` | `FOCUS` (border + outline) | FOCUS does **not** fill the control. [src] [sim] |
| Checked / on | `ACTIVE`     | `PRIMARY1`   | `SECONDARY2`   | Active buttons, toggles in on state. [src] [sim] |
| Editing      | `EDIT`       | `PRIMARY2`   |                | Text areas (`etx_lv_theme.cpp:666-668`). [src] [sim] |
| Disabled     | grey filter  | grey filter  |                | 50 % mix with a fixed light grey (`lv_palette_lighten(LV_PALETTE_GREY, 2)`), **not** `DISABLED` (`etx_lv_theme.cpp:203-217, 593`). [src] |
| Pressed      | darkened     | darkened     |                | Dark color filter (`styles->pressed`). [src] |

Toggle switch: track follows the table above (`PRIMARY2` off, `ACTIVE` on), knob is `SECONDARY1` (`libui/toggleswitch.cpp:46`). [src] [sim]

### Lists and tables (menus, choice popups, theme color list)

`libui/table.cpp:40-47`:

| Part             | Background | Text       | Notes |
| ---------------- | ---------- | ---------- | ----- |
| Item             | `PRIMARY2` | `PRIMARY1` | Separators `SECONDARY2`. [src] [sim] |
| Selected item    | `FOCUS`    | `PRIMARY2` | Measured slightly darker in the simulator (pressed filter). [src] [sim] |

### Bars, pages, dialogs

| Element                                  | Colors | Source |
| ---------------------------------------- | ------ | ------ |
| Page/dialog/popup body                   | `SECONDARY3` background (default of `etx_solid_bg()`, `libui/etx_lv_theme.h:155-157`) | [src] [sim] |
| TopBar, page header, dialog/menu header  | `SECONDARY1` background, `PRIMARY2` text/icons (`mainview/topbar.cpp:142`, `setup_menus/pagegroup.cpp:112-127`, `libui/dialog.cpp:56-57`, `libui/menu.cpp:318-319`) | [src] [sim] |
| Page icon / ETX logo tab                 | `FOCUS` background, `PRIMARY2` icon (`setup_menus/pagegroup.cpp:62-80`) | [src] [sim] |
| Footer (e.g. LS monitor)                 | `SECONDARY1` background, `PRIMARY2` text | [sim] |
| Label (`StaticText` default)             | `PRIMARY1` text, no own background (`libui/static.h:33`) | [src] [sim] |
| Scrollbar                                | fixed `COLOR_GREY`, not a theme slot (`etx_lv_theme.cpp:640-644`) | [src] |
| On-screen keyboard                       | `SECONDARY3` background; keys `PRIMARY2`/`PRIMARY1`, checked `ACTIVE`, selected `FOCUS` with `PRIMARY2` text (`libui/keyboard_base.cpp:27-42`) | [src] |

### Full-screen dialogs (`libui/fullscreen_dialog.cpp`)

| Part                    | Confirm/info type | Alert type (switch/throttle warning) |
| ----------------------- | ----------------- | ------------------------------------ |
| Background (top/bottom strips) | `SECONDARY1` [src] [sim] | **`WARNING`** (line 43) [src] [sim] |
| Middle band             | `PRIMARY2` (line 59) [src] [sim] | `PRIMARY2` [src] [sim] |
| Title and warning icon  | `WARNING` on `PRIMARY2` (lines 64, 81) [src] [sim] | same [src] [sim] |
| Message (e.g. switch list `SA↑`) | `PRIMARY1` bold on `PRIMARY2` (line 88) [src] | same [src] [sim] |
| Buttons                 | `SECONDARY3` background, `PRIMARY1` text, `FOCUS` border when focused (lines 97-116) [src] [sim] | same [src] [sim] |

Alert type is used by the switch and throttle warnings (`controls/switch_warn_dialog.cpp:27, 94`).

### Main view

| Element                 | Colors | Source |
| ----------------------- | ------ | ------ |
| Main screen background  | `background_<W>x<H>.png` if present, else `SECONDARY3` | [sim] |
| Slider                  | path `SECONDARY1`, knob `FOCUS`, knob shadow `PRIMARY1` (`mainview/sliders.cpp:37-57`) | [src] [sim] |
| Trim                    | bar `SECONDARY1`, value text `PRIMARY2` on `SECONDARY1` (`mainview/trims.cpp:100-120`) | [src] |
| Radio Info widget       | inactive icon parts `PRIMARY3` (`widgets/radio_info.cpp`) | [src] |
| Timer widget            | background `WARNING` when elapsed (`widgets/timer.cpp:44, 181`) | [src] |

### Where `WARNING` is used

Text: warning labels (e.g. `radio/hw_serial.cpp:68`, `module/custom_failsafe.cpp:46`, `module/module_setup.cpp:214`), stale telemetry values (`model/model_telemetry.cpp:181, 407`). **Fill:** full-screen alert, elapsed timer widget, USB joystick collision (`model/model_usbjoystick.cpp:354`). [src]

### Where `DISABLED` is used (complete list, v2.12.4)

| Place | Source |
| ----- | ------ |
| LS monitor: numbers of unused logical switches, drawn on `SECONDARY3` | `mainview/view_logical_switches.cpp:290` [src] [sim] |
| Value widget: label and value while telemetry is stale | `widgets/value.cpp:57, 69` [src] |
| Model templates: info text | `model/model_templates.cpp:57` [src] |
| USB joystick: bar of channels used elsewhere | `model/model_usbjoystick.cpp:106` [src] |
| Mic recorder: cut shade | `radio/radio_mic_recorder.cpp:118` [src] |
| Theme editor preview: "Disabled" sample label | `radio/preview_window.cpp:162` [src] [sim] |

### Quick Menu (2.12+)

`QM_BG` background, `QM_FG` icons/text/separator; the focused entry swaps them (`QM_FG` background, `QM_BG` icon and text). Disabled entries mix `QM_FG` in at 60 % (`setup_menus/quick_menu_group.cpp:33-37, 69-121`, `libui/etx_lv_theme.cpp:220-234`). [src] [sim, theme editor preview only]

---

## 5. Contrast pairs that must stay legible

Derived from §4. Check each pair (WCAG contrast ratio; the EdgeTX UI font is large, so about 3:1 is readable, 4.5:1 is comfortable):

| Foreground   | Background   | Where it shows                                   |
| ------------ | ------------ | ------------------------------------------------ |
| `SECONDARY1` | `PRIMARY2`   | Text on every button and field                   |
| `PRIMARY1`   | `PRIMARY2`   | List/menu items                                  |
| `PRIMARY1`   | `SECONDARY3` | Labels on pages and popups                       |
| `PRIMARY2`   | `SECONDARY1` | TopBar, page headers, dialog headers, footers    |
| `PRIMARY2`   | `FOCUS`      | Selected list entry; page icon / logo            |
| `PRIMARY2`   | `EDIT`       | Field while editing                              |
| `PRIMARY1`   | `ACTIVE`     | Checked buttons, toggles on                      |
| `FOCUS`      | `PRIMARY2` and `SECONDARY3` | Focus border must be visible around controls and tiles |
| `WARNING`    | `SECONDARY3` | Warning labels on pages                          |
| `WARNING`    | `PRIMARY2`   | Title/icon of full-screen dialogs                |
| `SECONDARY3` (button) | `WARNING` | Full-screen alert: only the button sits on the WARNING strips, no text |
| `PRIMARY1`   | `PRIMARY2`   | Message text of full-screen dialogs (e.g. switch warning) |
| `PRIMARY1`   | `SECONDARY3` | Full-screen dialog buttons                       |
| `DISABLED`   | `SECONDARY3` | LS monitor (unused switches)                     |
| `DISABLED`   | main-screen background | Value widget with stale telemetry      |
| `PRIMARY3`   | `SECONDARY1` | Inactive TopBar icon parts                       |
| `QM_FG`      | `QM_BG`      | Quick Menu (2.12+)                               |

Practical rules of thumb:
- **`PRIMARY2` is the control surface.** Buttons, fields and list items are filled with it, and it is also the text color on bars, FOCUS and EDIT. A dark `PRIMARY2` therefore needs light `SECONDARY1`/`PRIMARY1` text and light-to-mid `SECONDARY1`/`FOCUS`/`EDIT` fills.
- **`SECONDARY1` has a dual role**: bar background *and* control text. It must contrast with both `PRIMARY2` (as text) and carry `PRIMARY2` text on bars.
- **Focus is mostly a border.** On controls it is only an outline, so `FOCUS` must stand out against `PRIMARY2` *and* against `SECONDARY3` (tiles, grid items). Only the selected list entry is filled.
- **`WARNING` must work as text and as a fill.** Check it as text on `SECONDARY3` and `PRIMARY2`; as a fill it frames the alert screen, where the `SECONDARY3` button must still stand out from it.
- **`DISABLED` is text on `SECONDARY3`** in the LS monitor: a mid tone that is visible there but clearly weaker than `PRIMARY1`.
- If `SECONDARY3 == PRIMARY2`, controls separate from the page only by their `SECONDARY2` border (follows from §4).

---

## 6. Creating a theme

### Option A: edit `theme.yml` directly (fastest for full control)
1. Start from `templates/theme.yml` in this skill (a fully-commented 13-color file), or duplicate an existing theme folder under `/THEMES/` (e.g. copy the stock `EdgeTX` theme) so you inherit valid images.
2. Create/rename the folder under `/THEMES/`.
3. Edit `theme.yml`: set `summary.name`/`author`/`info`, then tune the 13 colors.
4. Walk the [contrast pairs](#5-contrast-pairs-that-must-stay-legible).
5. Copy to the radio's SD card `/THEMES/`, then on the radio: **Theme screen → long-press your theme → Set Active**.
6. Replace the screenshots/logo to match (optional but expected if you'll share it).

### Option B: on the radio (no PC needed)
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

These are **indexed** colors: change the theme and every script using them re-colors instantly. There is no Lua constant for `QM_BG`/`QM_FG`: those are OS-only. Prefer `COLOR_THEME_*` over the fixed legacy colors (BLACK/WHITE/RED…) so scripts respect the user's theme. See `api-reference.md` → Theme colors.

---

## 8. Pitfalls

- **Folder must be directly under `/THEMES/`**, one folder per theme. No nesting.
- **Start `theme.yml` with `---`** for compatibility with older EdgeTX versions (2.12 tolerates its absence). Bad indentation can make the radio skip the theme silently.
- **YAML indentation matters**: use spaces, not tabs; `name`/`author`/`info` are nested under `summary:`, the colors under `colors:`.
- **`description:` is not shown in the UI**: use `info:` for the user-visible blurb.
- **RGB565 truncation** (see [§2](#2-themeyml-format)): design with real radio rendering in mind, not pixel-perfect 24-bit.
- **`DISABLED` does not grey out disabled controls.** Disabled buttons, toggles and sliders get a fixed grey filter; `DISABLED` only colors the few texts listed in §4. Check it where it actually appears: the LS monitor (on `SECONDARY3`).
- **Don't make `DISABLED` equal to `PRIMARY1`**: unused switches in the LS monitor would look like defined ones.
- **`WARNING` is also a fill**: the full-screen alert (switch/throttle warning) and the elapsed timer widget paint their background with it. Pick a color that works as text *and* as a background.
- **Test on the actual display family.** A theme tuned on a bright 800×480 panel can look washed-out or muddy on a dimmer 480×272 unit.
- Editing a theme **in the radio editor overwrites its `theme.yml`**: keep a backup if you hand-tuned the file.

---

## 9. Verifying the map (diagnostic theme)

To check which slot paints what, give every slot its own signal color and look at the screens. This is how §4 was confirmed (TX16S MK3 simulator, 2026-09-26):

```yml
---
summary:
  name: Color Test
  author: -
  info: Diagnostic theme, every slot has its own signal color
colors:
  PRIMARY1:   0xFF0000   # red
  PRIMARY2:   0x0000FF   # blue
  PRIMARY3:   0xFF00FF   # magenta
  SECONDARY1: 0xFFFF00   # yellow
  SECONDARY2: 0x00FFFF   # cyan
  SECONDARY3: 0x804000   # brown
  FOCUS:      0x00FF00   # green
  EDIT:       0xFF8000   # orange
  ACTIVE:     0x8000FF   # purple
  WARNING:    0x008080   # teal
  DISABLED:   0xFFC0C0   # pink
  QM_BG:      0x404000   # olive
  QM_FG:      0xC0FFC0   # mint
```

Leave out the background images so the main screen shows `SECONDARY3`. Read the colors from screenshots by pixel value, not by eye; RGB565 turns `0xFFFF00` into `0xF8FC00`, and pressed/selected items are drawn slightly darker.

| Screen | Confirms |
| ------ | -------- |
| Radio Setup → Themes → Edit theme (preview) | Controls normal/focused/checked/editing, toggles, labels, TopBar, sliders, Quick Menu. The preview uses real `TextButton`/`TextEdit`/`ToggleSwitch` controls (`radio/preview_window.cpp:152-165`), but its "Disabled" label is hard-coded to `DISABLED`, so it proves nothing about disabled controls. |
| Theme editor color list, or any choice popup | List items and the selected entry |
| Quick Menu → Tools → LS Monitor (model without logical switches) | `DISABLED` on `SECONDARY3` |
| Model select with a model still connected ("Model still powered") | Full-screen dialog, confirm type |
| Switch SA away from its warning position, restart the simulator ("CONTROL WARNING") | Full-screen dialog, alert type with `WARNING` background |

Not yet confirmed in the simulator (source only): the grey filter on disabled controls, keyboard and trim colors, the timer widget fill.

