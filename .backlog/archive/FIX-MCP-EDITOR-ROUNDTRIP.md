# FIX-MCP-EDITOR-ROUNDTRIP — what the Mission Editor does to what the MCP writes

Status: ✅ done 2026-08-15 — all four tickets delivered; the task-survival fix (01) still wants one
in-game confirmation, David's step.

Origin: the 2026-08-15 DCS session, item 2 of `DCS-SESSION-TODO.md`. Six mutations were written into a
copy of the demo mission through the MCP, David opened it in the Mission Editor and saved it, and the
before/after tables were compared field by field.

## Why it took a human and a running editor

Every one of these actions is covered by unit tests, and every test passes. The tests assert what the
action **wrote**; they cannot assert what DCS **keeps**. Three of the six mutations survived untouched,
one was silently discarded, and one was overwritten by a recalculation — none of which any test in this
repository could have seen.

That is the entire value of the round-trip, and it is why ticket 02 of `FEAT-MCP-MUTATION-ACTIONS`
called it *"the only half no test can cover"*.

## What survived, and what did not

| Mutation | Verdict |
|---|---|
| Group moved 6 km, route attached | ✅ preserved exactly |
| Group renamed | ✅ preserved |
| Loadout cut to 6 stations | ✅ preserved |
| Trigger zone reshaped to **6 vertices** | ✅ **preserved** — see below, this settles an open question |
| Line + textbox on the Blue layer | ✅ both preserved |
| Waypoint removed, another ETA-relocked | ✅ the mission saves, so the relock was right |
| **`Bombing` task on a new waypoint** | ❌ **silently deleted by the editor** |
| **Unit heading set to 275°** | ⚠️ **overwritten** by DCS's own recalculation |

### The zone answer, which was an open question rather than a defect

`edit_zone` warns that the editor "only draws 4-point quad zones" and asks for a round-trip to find
out whether a 6-vertex polygon survives. **It does** — all six vertices came back byte-identical. So
the action does **not** need to refuse above four, and the warning can say this is measured rather
than feared. That is ticket 04 below, and it is a documentation change rather than a fix.

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | `add_task` writes an incomplete task the editor discards | ✅ |
| 02 | `edit_route add` ignores the altitude and speed it is given | ✅ |
| 03 | A heading set on a flying aircraft does not survive | ✅ |
| 04 | The 6-vertex zone survives — say so | ✅ |

01 is the one that matters: a task the editor deletes is a flight that quietly does nothing, which is
the failure mode `FEAT-MCP-MUTATION-ACTIONS` ticket 04 named as its worst case and could not test for.

## Definition of Done

- Each defect reproduced by a test written **before** its fix, against the measured field layout.
- The seven task kinds audited against real examples, not just `bombing`.
- Full Python gate green; coverage ratchet respected.
- The round-trip re-run in the editor for 01, since that is the only thing that proves it.

---

## 01 — `add_task` writes an incomplete task, and the editor deletes it

Status: ✅ done 2026-08-15 — all seven tasks compared to real examples; Bombing/AttackGroup weaponType + altitude/direction pairs, EngageTargetsInZone noTargetTypes
Type: fix
Files: `src/python/veaf-tools/veaf_mission_mcp/route_editing.py` (the task builders), tests

### What happened

A `bombing` task was added to a new waypoint through `edit_route`. The action reported success, the
resulting route showed the task, and the unit tests pass. David opened the mission in the editor and
saved it: the waypoint's `tasks` table came back **empty**.

Nothing warned. A mission maker would have flown a strike package that drops nothing.

### The measurement

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

### The rest of the family

`bombing` is one of seven task kinds the action accepts — `orbit`, `land`, `attack_group`, `bombing`,
`engage_targets_in_zone`, `set_frequency`, `switch_waypoint`. **They were all built the same way**, so
assume all seven are incomplete until each is compared against a real example. Enumerate them from the
builder table rather than sampling: the last time a family of defects was checked by hand-picking
cases, 3 of 13 were missed (`sweep-enumerated-not-sampled`).

Where to find real examples: `test-dawn-broken.miz` has `Bombing`; grep the repository's `.miz`
fixtures for each `id` before writing anything.

### TDD

- A test per task kind asserting the **exact** param set of a real example, so a missing key fails.
- The regression that reproduces this: `bombing` written without `weaponType` is the current output.

### Acceptance criteria

- [ ] All seven task kinds compared against a real example, and the gaps listed here.
- [ ] Params completed; tests pin the full set per kind.
- [ ] 🧑 The round-trip re-run in the editor — a task that survives a save is the only proof.
- [ ] Full Python gate green; coverage ratchet respected.

---

## 02 — `edit_route add` ignores the altitude and speed it is given

Status: ✅ done 2026-08-15 — add/insert honour altitude_ft/speed_kt; inheritance kept when omitted
Type: fix
Files: `src/python/veaf-tools/veaf_mission_mcp/route_editing.py`, tests

### What happened

```
edit_route(operation="add", name="ATTAQUE", altitude_ft=18000, speed_kt=350)
```

The waypoint was appended with the right name and position, and with **20000 ft / 449 kt** — the
values of the preceding waypoint. The two parameters were accepted, documented in the schema
(*"altitude in FEET and speed in KNOTS … the conversion is done for you"*) and silently dropped.

Found while preparing the 2026-08-15 editor round-trip, before the mission ever reached DCS.

### Why it is worth more than it looks

A caller cannot tell. The action returns the resulting route, so a careful reader sees 20000 where
they asked for 18000 — but the value they get is *plausible*, inherited from the neighbour rather
than absurd, which is the kind of wrong that survives review. A strike waypoint at the transit
altitude is a flight that does the wrong thing, not one that fails.

`set` presumably applies both (that path is what `altitude_ft` was written for). So the fix is likely
to be that `add` and `insert` never call the same code — worth checking `insert` in the same pass
rather than fixing only the operation that was caught.

### TDD

- `add` with `altitude_ft` and `speed_kt` produces exactly those values, converted — the test that
  fails today.
- The same for `insert`.
- A test that `add` **without** them still inherits from the previous waypoint, since that is the
  useful default and must not be broken by the fix.

### Acceptance criteria

- [ ] `add` and `insert` honour `altitude_ft` and `speed_kt`.
- [ ] Inheritance still applies when they are omitted.
- [ ] Full Python gate green; coverage ratchet respected.

---

## 03 — A heading set on a flying aircraft does not survive the editor

Status: ✅ done 2026-08-15 — warns for an airborne aircraft with a 2+ waypoint route; still writes the heading
Type: docs
Files: `src/python/veaf-tools/veaf_mission_mcp/unit_properties.py` (the result's warnings), the
mission-maker action catalogue (both languages), tests

### The measurement

`set_unit_properties(heading_deg=275)` on an airborne F-14B wrote `4.7996554` rad, correctly. After a
save in the editor the unit carries `-1.8224863` rad — which is **exactly** `atan2(Δy, Δx)` of its
route's first leg, to the seventh decimal.

So DCS is not corrupting the value: it recomputes an airborne aircraft's heading from where its route
sends it. The write was never wrong; it was irrelevant.

### Not a bug, and that is the point

This is why it is a docs ticket rather than a fix. Refusing the parameter would be wrong — heading is
meaningful on a parked aircraft, on a ground unit, on a ship. What is wrong is a result that says
`heading: from … to 275°` with no hint that the value has a lifetime of one save.

Note the interaction that made this visible: the same round-trip **removed a waypoint**, changing the
first leg. An unchanged route would have left the recomputed heading equal to the original, and the
overwrite would have gone unnoticed.

### What to do

Warn from the action when the heading is set on a unit that is **airborne with a route of two or more
waypoints** — the case where the recalculation applies. Name the reason: the route's first leg
decides, so set the route, not the heading.

Not measured, and therefore not claimed: whether a parked aircraft with a `TakeOffParking` waypoint is
also recomputed. State the warning's scope as what was measured, and leave the rest to a session that
measures it.

### TDD

- The warning fires for an airborne unit whose group has 2+ waypoints.
- It does **not** fire for a ground unit, nor for a single-waypoint group.
- The heading is still written in every case: the warning informs, it does not refuse.

### Acceptance criteria

- [ ] The warning ships, in both locales, scoped to what was measured.
- [ ] The catalogue page says a route beats a heading for an airborne unit.
- [ ] Full Python gate green; coverage ratchet respected.

---

## 04 — The 6-vertex zone survives the editor: say so, and stop hedging

Status: ✅ done 2026-08-15 — warning reworded to a measured limitation; no refusal above four
Type: docs
Files: `src/python/veaf-tools/veaf_mission_mcp/zone_editing.py` (the warning text), the mission-maker
action catalogue (both languages), tests

### The open question, now closed

`edit_zone` has shipped this warning since `FEAT-MCP-MUTATION-ACTIONS` ticket 06:

> 6 vertices: the VEAF runtime handles any polygon (mist.getUnitsInPolygon), but the DCS Mission
> Editor only draws 4-point quad zones — open the mission in the editor and save it once to confirm it
> keeps the shape

`DCS-SESSION-TODO.md` item 2 spelled out the stake: *"If it flattens it, the action should refuse
above four rather than warn."*

**It does not flatten it.** `czCrossKobuleti-1` was reshaped into a hexagon, opened in the editor and
saved on 2026-08-15; all six vertices came back unchanged, and so did `type: 2`. So the editor has no
UI for drawing a non-quad zone but preserves one it is given.

### What to change

- The action keeps writing any polygon, and **must not** start refusing above four.
- The warning stops asking for a confirmation that has been done. It should still say something —
  a maker who opens the zone in the editor cannot *edit* its shape there — but as a known limitation
  rather than an unknown risk.
- The catalogue says the same, in both languages.

### Careful

What is measured is that the editor **preserves the vertices through a save**. Not measured: what the
editor's UI shows for such a zone, nor whether dragging it in the editor rewrites the shape. Say what
was tested; a maker who drags the zone is outside it.

### TDD

- The warning text asserted, so the next reword keeps the meaning (a test already pins the vertex
  count warning — update it rather than adding a second).

### Acceptance criteria

- [ ] The warning states a measured limitation instead of asking for a round-trip.
- [ ] No refusal is introduced above four vertices.
- [ ] Catalogue updated in both languages; full Python gate green.
