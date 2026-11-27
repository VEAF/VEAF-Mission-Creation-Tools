# FIX-USER-REPORTS-985-989 — two user reports with no lot behind them

Status: ✅ done — verified in game 2026-10-03 (R22, and R15's group half) · archived 2026-11-24

Opened 2026-10-02 from a sweep of the backlog against the open issues: three reports from mission makers
had no lot — [#985](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/985),
[#989](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/989) and
[#953](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/953). David, 2026-10-02: one PR for
the first two, a reply drafted for the third, and the six lots closed for more than three days archived
in the same move.

## Tickets

| # | Ticket | Status |
|---|--------|--------|
| 01 | [the shipped spawnables sit under the CJTF countries](FIX-USER-REPORTS-985-989.md) | ✅ |
| 02 | [a dynamic-slot helicopter gets its CSAR menu](FIX-USER-REPORTS-985-989.md) | ✅ |
| 03 | [#953: what Tripack's 09-19 test settles](FIX-USER-REPORTS-985-989.md) | ✅ |

## Definition of done

- [x] No template of `src/defaults/mission-folder/src/spawnables.yaml` under a real country, pinned by a test that fails on the old file.
- [x] `csar.getGroupId` reads the live group, with a test that fails on the old code; `vendored.yaml` names the adaptation.
- [x] #953's static half recorded as a DCS behaviour in `known-limitations.yaml`, R15 updated, a reply drafted for David to post.
- [ ] R22 read in game.

## In-game check — 2026-10-03

From `FIX-IN-GAME-SESSION-2026-10-03`.

R22: a UH-1H taken from a dynamic slot shows `F10 Other… > CSAR` (David). #989 closed.

R15, the group half of #953: the QRA's Su-27 pair, `hidden = true` in the editor and recreated twice
by `coalition.addGroup`, never showed on a blue F10 map that did show a non-hidden red Shilka and
red MiG-29S. DCS keeps `hidden` on a recreated **group**; it drops it on a recreated **static**
(Tripack, 2026-09-19).

## Former index entry

The row this lot had in `.backlog/README.md` until the index was split into short summaries (CHORE-BACKLOG-INDEX-SPLIT, 2026-10-03), kept verbatim.

**two user reports with no lot behind them.** #985: 14 shipped spawnables under `USA`/`France`/`USSR` instead of the side-locked CJTF countries, now pinned by a test. #989: no CSAR menu in a dynamic-slot helicopter since CSAR left MiST (6.18.0) — `csar.getGroupId` read the editor snapshot, it reads the live group. Also records #953's static half as a DCS behaviour (a scripted static ignores `hidden`)

## Tickets, in full

## 01 — the shipped spawnables sit under the CJTF countries

Status: ✅ done 2026-10-02

[#985](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/985): 14 of the 51 templates of
`src/defaults/mission-folder/src/spawnables.yaml` were filed under `USA` (6), `France` (2) and `USSR`
(6). The injector adds a template's country to its side without checking the other, so a blue `France`
template in a mission where France is red lists France on both sides — the constraint the dynamic-slot
catalogue already pins (`test_dynslot_catalogue_invariants.py`).

### What was done

- The three country blocks directly followed `CJTF Blue` / `CJTF Red`, so dropping their three key
  lines merged them: 15 blue under `CJTF Blue`, 36 red under `CJTF Red`, 51 in all, ids unchanged.
- The six USSR MiG templates carried bare-number callsigns (`174`, `175`…), the Russian-style form
  `aircraft_identity.py` documents; a CJTF aircraft carries `{1, 2, 3, name}`. They now read
  `Springfield11` … `Springfield62`, family 2, one flight per template.
- `ShippedSpawnablesCountryTest` pins both: one country per side, western-shaped callsigns. Run against
  the old file it fails on all 14 templates and their 12 MiG callsigns.
- `smoke-test-mission`, `verify-mission-a` and `verify-mission-c` carried byte-identical copies of the
  old default; they get the new one. `demo-mission` has its own catalogue and is left alone.

## 02 — a dynamic-slot helicopter gets its CSAR menu

Status: ✅ done — verified in game 2026-10-03

[#989](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/989), Tripack 2026-09-22: no CSAR
radio menu in a UH-1, while the MAYDAY and the downed pilot showed CSAR running.

### Cause

`csar.addMedevacMenuItem` adds the menu to `csar.getGroupId(unit)`, and that function has looked the
unit up in `veaf.getUnitRecordById` since CSAR left MiST (#845, 2026-08-30, shipped in 6.18.0). That is
the **editor snapshot**, which by its own docstring answers nothing for a unit created at runtime — and a
dynamic slot is one. MiST's `mist.DBs.unitsById`, which it replaced, grew at every birth. So a
dynamic-slot helicopter got `nil`, hence no menu, and none of the messages CSAR sends to its group
(`delayedHelpMessage`, `displayMessageToSAR`). The VEAF configuration was not the cause:
`veaf.lua` already forces `enableAllslots = true`, so the UH-1H type is enough.

Not confirmed on Tripack's own files (they are on Discord), so "dynamic slot" is the inference from the
code, which R22 checks.

### What was done

- `csar.getGroupId` reads `_unit:getGroup():getID()`, the live group. `vendored.yaml` names the
  adaptation in CSAR's `manual_steps`.
- `test_a_dynamic_slot_helicopter_gets_its_csar_menu` (`test_csar_init.lua`) builds a UH-1 the editor
  never placed and asserts the `CSAR` submenu lands on its group id; it failed before the change with
  no menu at all.

## 03 — #953: what Tripack's 09-19 test settles

Status: ✅ done 2026-10-02 — reply drafted for David; the group half stays in `DCS-SESSION-TODO.md` R15

[#953](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/953) had no answer since Tripack's
test of 2026-09-19. On a v6 mission, from a blue slot and as Tactical Commander: neutral statics hidden
in the editor and touched by no script stay hidden; the identical ones a combat zone recreates show on
the map, and vanish and come back with the zone.

### Checked in the code

The zone puts a static back through `VeafGroupSpawn` → `veafDcsSpawner.addStatic`, which submits the
editor record's `hidden`, `hiddenOnMFD` and `hiddenOnPlanner` to `coalition.addStaticObject` —
`test_the_static_the_zone_puts_back_is_still_hidden` pins all three. So the flag is sent and DCS does not
apply it to a static a script created: R15's **Ignored** branch, for statics.

### What was done

- `dcs-scripted-static-ignores-hidden` added to `known-limitations.yaml`, `dcs-runtime-traps.md`
  regenerated.
- R15 records the result and narrows what is left to the group half (a red group recreated by
  `coalition.addGroup` — the QRA side of the report).
- A reply for Tripack, for David to post.

Not done, and a decision rather than a fix: whether a zone active at start should keep the editor's
own statics instead of destroying and recreating them, which is the only way to keep them hidden.
