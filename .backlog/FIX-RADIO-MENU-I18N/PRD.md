# FIX-RADIO-MENU-I18N — the F10 menu speaks English on a French server

Status: ✅ done — 2026-08-13, all three tickets

Origin: `DOC-MODULE-PAGES` (2026-08-13). Writing `veafCombatMission`'s page meant quoting its menu
labels from the code, and that is how the defect surfaced: the pilot guide promised
*« Zones de combat → [Zone] → Activer »* where the game shows `Combat Zones` → `Activate zone`. A
French-speaking pilot was looking for a label that does not exist. The documentation was corrected
there; the labels themselves are a code change, and this is it.

## The measurement

**90 menu labels are hard-coded English strings, across 12 modules**, while every player-facing
*message* already goes through `veaf.t`:

| Family | Count | Shape |
|--------|-------|-------|
| Static command entries | 71 | `veafRadio.addCommandToSubmenu("Get info", …)` |
| Entries composed with a dynamic part | 6 | `"Respawn " .. element.description` |
| Root menu names | 13 | `veafAssets.RadioMenuName = "ASSETS"` |

Per module: `veafCombatZone` 18, `veafWeather` 14, `veafSpawnCore` 11, `veafCasMission` 10,
`veafTransportMission` 10, `veafCombatMission` 8, `veafAssets` 5, `veafCarrierOperations` 4, and one
each in `veafMissileGuardian`, `veafMove`, `veafNamedPoints`, plus `veafRadio`'s own `VEAF` root.

## The trap this lot must not walk into

**`veaf.config.language` is set *after* the module files load and *before* the `initialize()` calls.**
Measured on a generated `veaf-config.lua`: `veaf.config.language = "en"` is the first line, then the
`initialize()` calls follow.

So a label resolved **at load time** — which is where `RadioMenuName = "ASSETS"` lives — would always
resolve in French, whatever the mission declares, **with no error**. Every label must be resolved
when the menu is *built*, inside `initialize()` → `buildRadioMenu()`. A test has to pin this, because
the failure mode is a silent wrong language rather than a crash.

## David's arbitrations (2026-08-13)

- **a — Translate everything, root menus included.** A menu half English and half French is the worst
  of the three states. French labels stay short and upper-case so the visual landmark survives
  (`COMBAT ZONES` → `ZONES DE COMBAT`). Consequence accepted: pilots lose the English vocabulary they
  know, and the pages written in `DOC-MODULE-PAGES` must quote labels in their own page's language.
- **b — Fix the typo.** `Desactivate zone` / `Desactivate mission` becomes `Deactivate …` in English.
  The string is moving anyway; this is the moment.
- Not chosen: a `radio_menu_language` config flag. A third state to test and document, for a need
  nobody has expressed.

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | [The 14 root menu names, and the load-time trap](tickets/01-root-menu-names.md) | ✅ |
| 02 | [The 77 entries, and the guard that forbids the next literal](tickets/02-menu-entries.md) | ✅ |
| 03 | [The pages that quote the old labels](tickets/03-documentation.md) | ✅ |

One branch, one PR.

## Definition of Done

- No `veafRadio.add*` call and no `RadioMenuName` carries a display literal any more, **proven by a
  test that enumerates them from the source** rather than by reading the diff.
- A test proves a label is resolved at build time, not at load time.
- The i18n coverage test covers the new keys in both languages.
- `test-lua` + stylua green; `docs-check` green; the pages quote the labels of their own language.

## What the work corrected in its own plan

- **14 root names, not 13.** `veafCarrierOperations` declares three (`RadioMenuName`,
  `…Blue`, `…Red`), which the PRD's count missed.
- **`veafShortcuts.RadioMenuName = "SHORTCUTS"` was dead code** — that module builds no radio menu and
  nothing reads the field. Removed rather than given a translation nobody would ever see.
- **`veafRadio` assigned its root title at load time** (`veafRadio.radioMenu.title =
  veafRadio.RadioMenuName`, line 58), which is the load-time trap in its purest form. The assignment
  moved into `initialize()`.
- **The guard's first version was a faux negative.** Written line-by-line, it saw **46 of the 77**
  literals: stylua wraps most `veafRadio.add*` calls, so the first argument sits on the next line. It
  would have reported a clean sweep with 31 English labels still in place. It is multi-line now, with
  a test asserting that very property — the guard needed its own guard.

## Decisions taken while implementing

- **`Get info` translates to `Infos`, not `Obtenir des informations`.** A radio menu entry has to fit
  on one line in the DCS overlay; the French labels are kept as short as the English ones.
- **A tasking order's zone name is not translated.** `"Briefing " .. zone:getFriendlyName()` becomes
  `veaf.t("menu.combatzone.briefing", name)` with a `%s`: the word is ours, the name is the mission
  maker's.
- **`veafCombatMission.DesactivateMission` keeps its spelling.** The typo is fixed in what a pilot
  *reads*; renaming a public Lua function would break third-party scripts for a cosmetic gain.
- **`MISSIONS`, `VEAF` and `GUARDIAN` are identical in both languages**, stated so a reviewer does not
  read them as an oversight.
