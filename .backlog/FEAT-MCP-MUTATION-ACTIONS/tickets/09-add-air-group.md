# 09 — `add_air_group`: a flight on the ramp, not a flight in a field

Status: ⬜ ready — blocked on [08](08-capture-parking-data.md) for the parking data
Type: feat
Files: `veaf_mission_mcp/add_group.py` (or a sibling), `actions.py`, the catalogue docs, `test/python/`

Depends on: [08](08-capture-parking-data.md) (parking slots per airfield). Split out of
[03](03-group-setters.md) on David's call, 2026-08-12.

## The use case

> *"Put a two-ship of F-16s on the ramp at Incirlik."*

`add_group` today inserts a **ground/vehicle** group. An aircraft group is different in kind, not in
degree: it needs a first waypoint that says *how it starts* — and DCS has four ways of starting, each
with its own waypoint shape, which is where a plausible-looking write goes wrong.

## What was measured before this ticket was written

From `test/veaf-tools/test.miz`, two real player flights:

```
Mustang4 F-14A   unit.parking = 28, unit.parking_id = 24
                 route.points[1] = { type = "TakeOffParking", action = "From Parking Area",
                                     airdromeId = 12, alt = 43, ETA_locked = true }

Elvis5 F-14A     unit.parking = 1,  unit.parking_id = 1
                 route.points[1] = { type = "TakeOff", action = "From Runway",
                                     helipadId = 58, alt = 0, ETA_locked = true }
```

Four things follow, and each is a way to get it wrong:

1. **The two parking numbers differ** (28 vs 24). Both are written, and inventing either puts the
   aircraft somewhere nobody asked for. This is what blocks the ticket on 08.
2. **`airdromeId` and `helipadId` are alternatives**, not synonyms: a real airfield uses the first, a
   carrier or FARP the second. Writing both, or the wrong one, is a mission the editor may open and
   DCS may not fly.
3. **`ETA_locked` is `true` on the first waypoint of both.** `FIX-WAYPOINTS-ETA-LOCKED` established
   why: DCS **refuses to save** a mission whose route has no locked-time waypoint, and the fix there
   was to lock the first when nothing else is locked. A generated route must do the same.
4. **The start altitude is not zero for a parked aircraft** (43 m at Incirlik's elevation, 0 for the
   runway case where DCS resolved it). Worth checking against the terrain elevation rather than
   hardcoding.

## Decide while doing it, not now

- **Does this belong beside `create_cap_mission`?** The triage's open question. A mission maker asking
  for "a two-ship on the ramp" may be better served by the existing composite, which already knows
  VEAF's naming conventions and its QRA/CAP wiring. Compare them **with the composite open**, and if
  the composite wins, this ticket is a rejection with a reason — an acceptable outcome.
- **How is a stand chosen?** By slot id (precise, needs the maker to know it), by "any free stand"
  (needs to know what the mission already occupies), or by "the nearest to the runway"
  (`fDistToRW`-like, if a capture actually reports it). Naming a stand nobody can enumerate is not an
  interface.
- **What happens on a collision?** Two groups on the same stand is a mission that loads with aircraft
  merged into one another. This action can see the mission it is writing to, so it can refuse — but
  only if the stands already taken are readable, which is the same data question.

## Tasks

- [ ] Aircraft group insertion with a correct first waypoint per start type: parking, runway, hot
      start, air start.
- [ ] Parking slots resolved from the committed capture, refusing an unknown airfield or slot by name
      rather than writing a number DCS will reinterpret.
- [ ] A stand already occupied in the mission is refused, naming the group that holds it.
- [ ] `ETA_locked` honoured on the first waypoint, per `FIX-WAYPOINTS-ETA-LOCKED`.
- [ ] Catalogue doc + developer reference updated in this ticket (the `docs-check` gate enforces the
      second one).

## Acceptance criteria

- [ ] Round trip through the DCS Mission Editor with no complaint, **and** the flight starts where it
      was put — the editor accepting a parking id is not proof DCS parks the aircraft there.
- [ ] Tests per start type, plus the refusal paths (unknown airfield, unknown slot, occupied slot).
- [ ] `ruff` / `mypy` / `pytest` green over the whole tree; coverage gate bumped per the ratchet.
