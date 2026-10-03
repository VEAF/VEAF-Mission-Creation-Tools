# FIX-CAP-SIDE-TEMPLATES — a red `-cap` draws red templates

Status: ✅ done — verified in game 2026-10-03 (R32); #240 closed

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
| 01 | [A `-cap` or `-afac` draws from its own side](tickets/01-draw-from-the-requesting-side.md) | ✅ |
| 02 | [Vendored DCS schema `v0.4.0`](tickets/02-dcs-schema-v0-4-0.md) | ✅ |
| 03 | [#1007 is a VMCT issue](tickets/03-issue-1007-references.md) | ✅ |

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
