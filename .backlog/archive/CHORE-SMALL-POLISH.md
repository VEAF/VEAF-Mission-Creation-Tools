# CHORE-SMALL-POLISH — four small things David noted on 2026-09-29

Status: ✅ done (PR #1026, merged 2026-09-29) · archived 2026-10-03

Noted by David while testing, grouped so they ship together rather than as four lots. None of them
blocks anything; each is small on its own.

## Tickets

| # | Ticket | Status |
|---|--------|--------|
| 01 | radio kneeboards mangle non-ASCII names | ✅ |
| 02 | an icon on `veaf-logs.exe` | ✅ |
| 03 | every first-level radio menu in capitals | ✅ |
| 04 | `veaf-logs`: a button to show or hide the filter panel | ✅ |

## Definition of done

- Each ticket closed with what was measured, not only what was changed.
- Tests for 01, 03 and 04; 02 checked on a built `veaf-logs.exe`.
- `CHANGELOG.md` entry; `doc/` updated where a menu name or a screenshot changes.

## Tickets, in full

## 01 — radio kneeboards mangle non-ASCII names

Status: ✅ done

David, 2026-09-29: the radio kneeboards do not handle UTF-8 well; example *Nörvenich* on
Germany-v6.

### Measured before starting (2026-09-29)

- Our own tables spell it **`Norvenich`**, without the umlaut
  (`veaf_libs/data/airdromes.yaml`, `airfield-frequencies.yaml`). So the `ö` reaches the kneeboard
  from somewhere else: the mission's own names, DCS's airbase name, or a preset label. **Where it
  comes from is the first thing to establish**, on Germany-v6's generated kneeboard.
- The kneeboards are drawn with Pillow in `presets_injector/presets_manager.py` (~line 1923):
  `arial.ttf`, falling back to `ImageFont.load_default()` when Arial cannot be loaded. The default
  bitmap font has no glyph for `ö`, so a machine without Arial would draw a box. The other
  candidate is a decode somewhere on the way (Latin-1 read as UTF-8, or the reverse), which
  would draw `Ã¶`.

### Done when

- The kneeboard of Germany-v6 shows `Nörvenich` correctly.
- A test draws a name with a non-ASCII letter through the real path and asserts the text that
  reaches the drawing call, so a decoding error is caught; the font fallback is covered too.

### Closed (2026-09-29)

- **Where the `ö` comes from: the mission's own `presets.yaml`** (`Base-Norvenich: title: Nörvenich`,
  bytes `C3 B6`), read by `PresetsManager.read_yaml` with no `encoding=`, so with the locale's code
  page — `cp1252` on David's machine — which gives `NÃ¶rvenich`. Neither DCS nor the font.
- **The decoding fix is not in this lot.** Another session was writing it at the same time on
  `fix/presets-yaml-utf8` (every text `open()` of veaf-tools, with a test that fails on one opened
  without `encoding=`). David chose to leave it there rather than ship it twice.
- **The font hypothesis was wrong, measured:** with Pillow 12.3, `ImageFont.load_default()` is a
  FreeType font (FreeType is in the wheels) and draws the `ö`. Its real defect was the size: the
  three kneeboard fonts all fell back to 10 px instead of 18/30/40. Fixed with `load_default(size)`.
- Tests (`test_kneeboard_non_ascii.py`): a non-ASCII channel title reaches Pillow's `text()` call
  unchanged; without Arial, the fallback keeps the three sizes and draws the umlaut.

## 02 — an icon on `veaf-logs.exe`

Status: ✅ done

David, 2026-09-29: put an icon on the `veaf-logs` executable.

`veaf-logs.spec` builds the `EXE(...)` with no `icon=` argument, and no `.ico` exists in the
repository today. So the work is: an `.ico` (with the sizes Windows asks for, 16 to 256 px), the
`icon=` argument in the spec, and the same icon as the Qt window icon so the taskbar and the title
bar match the file.

### Done when

- The built `veaf-logs.exe` shows the icon in Explorer, and the running window shows it in the
  taskbar.
- Where the icon comes from is written down (drawn for the project, or taken from VEAF's own
  artwork with the right to use it).

### Closed (2026-09-29)

- **Where the icon comes from: drawn for the project** with Pillow — a log page titled DCS, with
  level-coloured lines (grey, amber, red), under a magnifier. David chose it over a Flaticon icon,
  which would have needed an author credit. No existing artwork was used.
- `src/python/veaf-tools/veaf_logs/veaf-logs.ico`, sizes 16, 24, 32, 48, 64, 128 and 256 px.
  `veaf-logs.spec` puts it on the executable (`icon=`) and ships it next to the module like
  `rules.json` (`datas`); `run()` sets it as the application's window icon
  (`veaf_logs.appearance.APP_ICON_PATH`); `pyproject.toml` ships it in the wheel.
- **Checked on a built `dist/veaf-logs.exe`:** PyInstaller logs "Copying icon to EXE", and the icon
  Windows extracts from the file (`ExtractAssociatedIcon`, 32 px) is this one. The running window's
  taskbar icon was **not** looked at; `test_icon.py` checks that Qt loads the icon with its 16 px size.

## 03 — every first-level radio menu in capitals

Status: ✅ done

David, 2026-09-29: put every first-level radio menu in capitals.

### To settle while doing it

- **Enumerate** the first-level entries from the code (every module that adds a menu under the VEAF
  root), not from a screenshot.
- Where the capitals are applied: once, where the first level is built in `veafRadio.lua`, rather
  than in each module's title. That is the only way a module added later follows the rule, and it
  leaves the French and English titles in `veafI18n.lua` as they are.
- The mission-maker docs quote menu names: every page that shows a first-level entry changes with
  it, in both languages.

### Done when

- A test builds the radio menu with the real modules and asserts that every first-level title is in
  capitals, including one registered after the others.

### Closed (2026-09-29)

- **Enumerated from the code:** 15 first-level menus (every `veafRadio.addMenu`, and every
  `addSubMenu` without a parent — Skynet's per coalition) plus 2 first-level commands (veafAssist's
  confirm / skip the step). **14 menus were already in capitals** in `veafI18n.lua`; only
  `Assistance` and the two commands were not.
- Applied once, in `RadioMenuBuilder:_buildSubtree`, to the display label of every child of the
  root — menus and commands, on every "Next page" of the root too (the 17 entries overflow the first
  page). The logical titles stay as written, since modules find their entries again by title.
- `veafRadio.toUpperCase` also upper-cases UTF-8 accented letters (à..þ, œ), which `string.upper`
  leaves alone ("Météo" would have become "MéTéO").
- Tests: `TestVeafRadioFirstLevelCapitals` renders the real first-level keys in French and English
  plus a lower-case module registered after them, and checks deeper levels are untouched.
- Docs: the pilot guide and README, the scripts index and the veafAssist page (FR+EN) quote the
  first-level names in capitals; the veafAssist page now shows the real labels of its two commands
  ("Valider cette étape" was not what the game shows).
- **Also fixed, at David's request:** the French pages quoted English labels — `ASSETS` for `MOYENS`,
  `CARRIER OPS` for `OPS PORTE-AVIONS`, and `veafAssets.md` claimed its commands were in English
  when they are translated (*Réapparition de*, *Infos sur*, *Retirer*). The pilot guide's diagram
  showed a first-level `Aide` / `Help` the code does not create (removed), and hung the carrier menu
  off F10 instead of VEAF. The carrier start command itself is hard-coded in English in
  `veafCarrierOperations.lua`, so the French index keeps quoting it that way.

## 04 — `veaf-logs`: a button to show or hide the filter panel

Status: ✅ done

David, 2026-09-29: a button in `veaf-logs` to show or hide the filter panel on the left, to give the
log text more width.

### Where it sits

`MainWindow` puts `self.side` (`SidePanel`, `veaf_logs/ui/panels.py` — levels, sources, ED noise,
context width) and the right-hand column in a horizontal `QSplitter`
(`veaf_logs/ui/main_window.py`, `splitter.setSizes([320, 1180])`). Dragging the handle to the edge
already collapses it, but nobody finds that, and it does not come back at a known width.

### To settle while doing it

- A checkable action, in the toolbar or the profile bar, with a keyboard shortcut; hiding the panel
  hands its width to the text, showing it restores the width it had before.
- Whether the state is remembered across restarts, like the open tabs are (`veaf_logs/session.py`).
- The filters keep applying while the panel is hidden, and something visible says so (the chips bar
  already shows the active filters — check it is enough).

### Done when

- A test toggles the action and asserts the panel's visibility and the width restored.
- `doc/mission-maker/LOGS.md` and `LOGS.en.md` mention the button and its shortcut.

### Closed (2026-09-29)

- A checkable *Panneau des filtres* action (`Ctrl+B`, the usual "toggle side bar" key, free here) in
  the *Affichage* menu, carried by a button at the start of the profile bar.
- **Measured:** `QSplitter` already gives a hidden widget its width back, a window resize in between
  included — a hand-written width memory was removed once the test passed without it. The one case
  Qt does not cover is a panel collapsed with the handle, which would come back at zero width: it is
  given the default 320 px. `sizes()` still reads zero right after `setVisible(True)`, hence the
  `splitter.refresh()` before the check.
- **The chips bar is not enough** to say filters are active: it only shows text filters, not levels,
  sources or ED noise. The status bar's "N masquees par les filtres" already covers all of them, so
  nothing was added.
- Remembered across restarts (`Session.filters_visible`), like the detail pane.
- Tests (`TestPanneauDesFiltres`, 6), each checked to fail when its guard is removed. Docs: `LOGS.md`
  / `LOGS.en.md`.
