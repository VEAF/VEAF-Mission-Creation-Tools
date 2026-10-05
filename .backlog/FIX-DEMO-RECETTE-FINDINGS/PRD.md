# FIX-DEMO-RECETTE-FINDINGS — what the first bridge recette of the demo found

Status: ⬜ ready

## Origin

On 2026-10-05 the v6 demo mission (`VEAF/VEAF-Demo-Mission-v6`) got an automatic recette: `tools/recette_pont.py` runs, in the loaded test mission and over dcs-bridge, the probes each guided-tour step carries (`probe` in `tour/steps.yaml`, helpers in `tools/recette-lib.lua`).
Its first run, on a test build `6.27.0+28c606b3` in French, found four VMCT defects, listed as n° 18 to 21 in the demo's `docs/retours-vmct.md`.
N° 18 (the MISSIONS menu is never built) went to 6.28.0 as its own lot, `FIX-COMBATMISSION-MENU-MISSING`; this lot carries the other three, for the next release.

The test bench: `python tools/build_candidate.py` in the demo builds it with this checkout; load `missions-test/VEAF_Demo_TEST_FR.miz` in DCS with dcs-serve running; `python tools/recette_pont.py sandbox` replays the marker probes.
`R.marker` in `tools/recette-lib.lua` sends VEAF the same `S_EVENT_MARK_CHANGE` a player's marker sends.

## The findings

| # | Defect | Measured |
|---|--------|----------|
| [01](tickets/01-destroy-radius-misses-units.md) | `_destroy, radius …` spares every unit whose name `Unit.getByName` cannot resolve | `-menage` (`_destroy, radius 2000`) left the `-armor` platoon alive at 1 295 m; `veaf.findUnitsInCircle` returned its three units, `Unit.getByName("[r]-Armored Platoon#10252 - IFV BMP-3 [CH]")` returned nil |
| [02](tickets/02-fog-commands-untranslated.md) | The fog commands of the WEATHER AND ATC menu are not translated | « Animated HEAVY fog over 1 minutes », « Static SPARSE fog »… in a `language: fr` mission, under translated submenus |
| [03](tickets/03-cas-group-name-sticks-to-blue.md) | After one blue CAS, every later CAS group is named « Blue CAS Group » | a red CAS group from a blue player's `_cas` marker was named « Blue CAS Group » (coalition 1) |

## Definition of done

- Each defect reproduced by a test that fails before the fix.
- `CHANGELOG.md` entries under `[Unreleased]`, one PR into `develop`.
- In DCS: the demo's `python tools/recette_pont.py sandbox generated` green on a fresh test mission (ticket 01 is what turns the `-menage` probe green); ticket 02 seen in the FR menu.
- The demo's `docs/retours-vmct.md` updated (n° 19 to 21).
