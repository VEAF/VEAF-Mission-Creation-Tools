# 01 — `add_task` writes an incomplete task, and the editor deletes it

Status: ✅ done 2026-08-15 — all seven tasks compared to real examples; Bombing/AttackGroup weaponType + altitude/direction pairs, EngageTargetsInZone noTargetTypes
Type: fix
Files: `src/python/veaf-tools/veaf_mission_mcp/route_editing.py` (the task builders), tests

## What happened

A `bombing` task was added to a new waypoint through `edit_route`. The action reported success, the
resulting route showed the task, and the unit tests pass. David opened the mission in the editor and
saved it: the waypoint's `tasks` table came back **empty**.

Nothing warned. A mission maker would have flown a strike package that drops nothing.

## The measurement

What the action writes, against a real `Bombing` read out of `test-dawn-broken.miz` (group `Bomber - 1`):

| Param | Written by us | Real task |
|---|---|---|
| `x`, `y` | ✅ | ✅ |
| `expend` | ✅ `"All"` | ✅ `"All"` |
| `attackQty`, `attackQtyLimit` | ✅ | ✅ |
| `groupAttack` | ✅ `false` | ✅ `false` |
| **`weaponType`** | ❌ **absent** | **`2032`** |
| **`altitude`** | ❌ absent | `6096` |
| **`altitudeEnabled`** | ❌ absent | `false` |
| **`direction`** | ❌ absent | `4.0491638646268` |
| **`directionEnabled`** | ❌ absent | `false` |

Six params written where eleven are expected. `weaponType` is the prime suspect — without it DCS has
no idea what to drop — but **do not fix on that assumption**: add the five, confirm the task survives a
save, then remove them one at a time if it is worth knowing which is load-bearing.

Note the shape of the two `*Enabled` pairs: the real task carries `altitude` **and** `altitudeEnabled:
false`. So DCS wants the field present and the flag off, not the field missing. A "leave it alone"
option is still a written value here.

## The rest of the family

`bombing` is one of seven task kinds the action accepts — `orbit`, `land`, `attack_group`, `bombing`,
`engage_targets_in_zone`, `set_frequency`, `switch_waypoint`. **They were all built the same way**, so
assume all seven are incomplete until each is compared against a real example. Enumerate them from the
builder table rather than sampling: the last time a family of defects was checked by hand-picking
cases, 3 of 13 were missed (`sweep-enumerated-not-sampled`).

Where to find real examples: `test-dawn-broken.miz` has `Bombing`; grep the repository's `.miz`
fixtures for each `id` before writing anything.

## TDD

- A test per task kind asserting the **exact** param set of a real example, so a missing key fails.
- The regression that reproduces this: `bombing` written without `weaponType` is the current output.

## Acceptance criteria

- [ ] All seven task kinds compared against a real example, and the gaps listed here.
- [ ] Params completed; tests pin the full set per kind.
- [ ] 🧑 The round-trip re-run in the editor — a task that survives a save is the only proof.
- [ ] Full Python gate green; coverage ratchet respected.
