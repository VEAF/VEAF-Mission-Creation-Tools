# FIX-RECON-OT-FINDINGS — recon photos one combat zone at a time

Status: 🧑 waiting-human

Origin: the recon photos of the eight Open Training missions (2026-11-17/18, VMCT 6.37.0): 203 photos for 215 zones, taken with local scripts that worked around the recon commands.
David validated the result (plural category labels, one ring per group, DCS's own screenshot with the window in the background); this lot brings that behaviour into `veaf-tools dcs recon-*`.

## Problem

Measured during the shoot:

1. `recon-prepare` prepends `veaf.HideNamesFromSpawnedGroups = false` to `veaf-config.lua`, and the mission's own config sets it back to `true` a few lines below: 227 shots out of 236 carried a random name, impossible to tie to a zone.
2. Every zone is active at once: the easy, medium and hard variants of a site share the same trigger zone, and one photo shows the three superimposed.
3. `recon-shoot` grabs the Windows screen: the DCS window must stay in front, the user loses the computer.
4. Long camera jumps leave the terrain blurred after 2.5 s (Falklands: 4 photos out of 26); positions are read once, before the camera moves, so a fast boat is ringed hundreds of metres away from where it is.
5. `recon-plan` lists every red unit of the map (AWACS, tankers, EWR), proposes a slant of 18 km for a spread zone, and crashes when the folder of `--out` does not exist.
6. `mark: groups` never rings a moving vehicle — on a battle, nothing is ringed; a zone of statics gets one ring and one label per static, stacked in a column.
7. A `_RECON` copy whose triggers did not load the spawn database (`VEAF_MapKey_SpawnData`) left every `#command` zone empty (not reproduced).
8. The shipped spawn database's `Red Manpad Squad` and `Red EWR` call `MANPADS SA-18 Igla "Grouse" C2`, a unit DCS does not know.

## What to build

- [01 — recon-prepare: names shown last, spawn database checked, zones left alone](tickets/01-recon-prepare.md)
- [02 — recon-plan: one shot per combat zone](tickets/02-recon-plan-zones.md)
- [03 — recon-shoot: one zone at a time, DCS's own screenshot, positions read at the grab](tickets/03-recon-shoot-zone-by-zone.md)
- [04 — recon-render: one ring per group, plural category labels, close rings merged](tickets/04-recon-render-categories.md)
- [05 — spawn database: the SA-18 command post's type](tickets/05-sa18-command-post.md)

Out of scope: `veaf-tools-updater.exe` saying 6.37.0 is up to date over a 6.36.0 exe (its own lot); a short default slant for small fast boats (Tiran, Abu Musa failed at 2 km as well — recorded as a known limitation).

Done when: the four commands take the photos of an Open Training mission end to end without a local script, with tests and `doc/CLI_REFERENCE.md` (#recon-photos) up to date; checked in game with David.
