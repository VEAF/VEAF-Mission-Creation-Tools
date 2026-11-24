# FIX-CAP-SIDE-TEMPLATES — a red `-cap` draws red templates

Status: ✅ done — verified in game 2026-10-03 (R32); #240 closed · archived 2026-11-24

Origin: [#240](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/240) (veaf-Sharko, 2023-08),
confirmed in game on 2026-08-17 by `CHORE-ISSUE-VERIFY-SESSION`; option **a** chosen by David on
2026-10-03. The same pull request carries two small items from the 2026-10-02 review: the
`dcs-schema` pin bump the drift watch reports on #618, and the wrong #1007 references.

## The defect

`-cap` is `_spawn cap, name`; with no name, the pattern is `.*` and every `veafSpawn-` template is a
candidate. `veafSpawn.initializeAirUnitTemplates` collects them with `veaf.getGroupsOfCoalition()`
**without a side** — red, blue and neutral in one pool — and the drawn template is then spawned in the
requester's country. `VeafAirUnitTemplate:setCoalition` existed and was never called.

Shipped `spawnables.yaml`, counted on 2026-10-03:

| side | templates | airframes |
|---|---|---|
| blue | 15 | F-15C ×8, M-2000C ×2, F-14A-135-GR ×2, F-4E, F-5E-3, MQ-9 |
| red | 36 | MiG-21Bis ×6, MiG-23MLD ×8, MiG-25PD ×8, Mirage-F1EE ×8, M-2000C ×6 |

A red `-cap` drew from 51 templates, 29 of them western airframes (57 %) — consistent with the
**7 out of 10** measured in game. The archived verdict *"the cause is data rather than code"* was
half wrong: the two F-15C of that session can only come from the **blue** templates, since red holds
none. `-afac` goes through the same function and had the same hole (a red AFAC could be the blue
MQ-9).

## The fix (option a)

- Each template records its side at load (`group:getCoalition()`).
- `findSpawnableAircraftGroupname(name, side)` keeps only the matching templates of `side` **and the
  neutral ones**. Neutral templates belong to nobody, and mission makers park them there: 61 of the
  117 `veafSpawn-` templates of the reference mission in `FIX-GETGROUPDATA-SKIPS-NEUTRALS`, the 14
  MiG-29 among them. A strict side filter would have made them unreachable as soon as the side had a
  template of its own — a refinement of option a, decided while implementing.
- When none of those matches, the draw falls back to every match and says so in `dcs.log`: a
  mission that placed its templates on one side only keeps spawning them for both.
- `spawnCombatAirPatrol` and `spawnAFAC` pass the side they already compute from the country.

Not changed, on purpose: the red Mirage templates stay (they are the "EASY / Radar OFF" training
adversaries). With the filter a red `-cap` still draws a Mirage 14 times in 36; `-cap mig` keeps to
MiGs.

## Tickets

| # | Ticket | Status |
|---|---|---|
| 01 | [A `-cap` or `-afac` draws from its own side](FIX-CAP-SIDE-TEMPLATES.md) | ✅ |
| 02 | [Vendored DCS schema `v0.4.0`](FIX-CAP-SIDE-TEMPLATES.md) | ✅ |
| 03 | [#1007 is a VMCT issue](FIX-CAP-SIDE-TEMPLATES.md) | ✅ |

## Definition of done

- [x] Tests that fail without the fix (4 of the 6 new ones; the fallback and the no-side cases guard
  today's behaviour) and pass with it; the whole Lua suite green.
- [x] `doc/mission-maker/concepts/spawnables.md` / `.en.md` say the side matters.
- [x] CHANGELOG under `[Unreleased]`.
- [ ] In-game check: a red `-cap` ten times, no F-15C, no F-14/F-4/F-5/MQ-9.

## Not claimed

Not flown in DCS. The evidence stops at the mocks; the in-game check is David's.

## In-game check — 2026-10-03

From `FIX-IN-GAME-SESSION-2026-10-03`.

Ten `_spawn cap, side red`: Su-30, MiG-25PD, MiG-29S, MiG-29A, Mirage 2000-5, Mirage F1EE, MiG-21Bis
×2, MiG-23MLD, JF-17 — red templates only.

## Former index entry

The row this lot had in `.backlog/README.md` until the index was split into short summaries (CHORE-BACKLOG-INDEX-SPLIT, 2026-10-03), kept verbatim.

**a red `-cap` draws red templates (#240).** The `veafSpawn-` templates of every side went into one pool and the drawn one spawned in the requester's country: on the shipped catalogue a red `-cap` drew from 51 templates, 29 of them western — 7 out of 10 in game, two of them F-15Cs that only blue holds. `-cap` and `-afac` now draw from their own side, falling back to every side when theirs has none. Same PR: the vendored DCS schema to `v0.4.0` (upstream fixed its `country.name` off-by-one) and the #1007 references corrected to this repository. Merged in #1052; the in-game check is R32

## Tickets, in full

## 01 — a `-cap` or `-afac` draws from its own side

Status: ✅ done — verified in game 2026-10-03

`veafSpawn.initializeAirUnitTemplates` records each template's side;
`veafSpawn.findSpawnableAircraftGroupname(name, side)` draws from that side's matches and the neutral
ones, falling back to every match (with a `dcs.log` warning) when none of those matches;
`spawnCombatAirPatrol` and `spawnAFAC` pass their side.

### Acceptance

- `test/lua/test_veafSpawn.lua`: the side is recorded at load; with one template per side, each side
  gets its own whichever candidate the draw picks; a neutral template serves both sides without
  letting the other side's back in; a side with no template falls back; a call with no side still
  sees every template; `-cap` and `-afac` pass their side.
- Without the fix, the side-recording, own-side, neutral and caller tests fail.

## 02 — vendored DCS schema `v0.4.0`

Status: ✅ done — 2026-10-03 (PR #1052)

The drift watch reports `YoloWingPixie/dcs-world-schema` `v0.3.5` → `v0.4.0` (released 2026-10-02).
Re-download `dcs-world-api-schema.json` and `dcs-world-api.lua` verbatim, bump `vendored.yaml` and the
`NOTICE`.

### Measured

- `audit-dcs-mocks` gives the same report on `v0.3.5` and `v0.4.0`: 0 missing mock, 12 used calls
  absent from the schema, 14 mocks never used.
- Upstream fixed the off-by-one in `types["country.name"]` (YoloWingPixie/dcs-world-schema#22): 92
  names, every one the inverse of `types["country.id"]`. The `NOTICE`, the developer README (FR/EN)
  and the `dcs_mocks.lua` comment said it was broken; they now say it was, until `v0.3.5`.
- `test_vendored_schema_country_ids.py` gains a test asserting the name table is the inverse of the
  id table — it fails on `v0.3.5`, passes on `v0.4.0`.

### Not checked

`v0.4.0` changes types (PascalCase task ids, typed ids). That reaches only LuaLS hints in a
contributor's editor through `.luarc.json`; no CI step reads the annotations.

### What the bump exposed

The support bot's `find_callers` validated only the last dotted segment of a function name, so its
test feeding `convert_fixture(); import os; os.system` searched for `system(`. It stayed green only
while no file in the checkout held that text; `v0.4.0` has one in a comment (`Link 4 system (label
only)`), and the bot's `quality` job went red on this PR. Fixed in `traces.py`: every segment must
be an identifier.

## 03 — #1007 is a VMCT issue

Status: ✅ done — 2026-10-03 (PR #1052)

Three places cited #1007 as `VEAF-Open-Training-Mission-GermanyCW-v6#1007`; the issue lives in this
repository. Corrected in the 6.26.0 CHANGELOG entry, the `FEAT-CTLD-AIRBASE-LOGISTICS` PRD and the
comment in `veafTransportMission.lua`. The 6.26.0 GitHub release body does not cite it, so nothing
published needs editing.
