# 03 — Group setters

Status: ✅ done 2026-08-12 — shipped as `set_group_properties`. `add_air_group` **left this ticket** for [09](09-add-air-group.md), on David's call: it needs parking data nobody has yet
Type: feat
Files: `src/python/veaf-tools/veaf_mission_mcp/`, mission-maker catalogue doc, `test/python/`

Depends on: 01 for the final field list; the use case below is already committed.

## The use case

> *"Move that group 5 km east."*

The second of the three the exploration note names. dcs-sms has 23 group verbs; this is the subset a
VEAF mission maker would actually ask for.

## Behaviour

**Move** is the one with a real design question, and it is not "set x and y":

- A group is not a point — it is units in a formation, plus possibly a route. Moving it must
  translate **every unit and every waypoint by the same delta**, or the formation shears and the
  route detaches from the units.
- Take a bearing and a distance, or a target coordinate, and reuse the existing geodesic offset from
  `FEAT-GEO-PLACEMENT` rather than adding metres to `x` — the projection work is already done and
  ADR 0015 owns it.
- The destination has to be checked: dropping a ground group in the sea is the failure this makes
  easy. Surface-type validation belongs here, and it is the design-time cousin of the runtime
  `veaf.findSpawnPoint` shipped by `FEAT-SCENERY-AWARE-SPAWN`.

**Rename** must respect the reserved VEAF naming conventions the MCP already knows
(`validate_group_name`, `describe_naming_conventions`) — a rename that breaks a convention breaks the
runtime module that keys off it, silently, at mission time.

**Late activation / hide / uncontrolled** are plain booleans and cheap.

**Frequency** must not be set blind: `FIX-PRIMARY-FREQ-HUMANRADIO` established that an aircraft has
two constraints (`panelRadio.range` for presets, `HumanRadio` for the group's primary) and that
ignoring the second makes the editor refuse to save the mission. Reuse `dcs-radio-specs.yaml`, do not
re-derive.

## The surface check cannot be delivered, and that is a measurement

The ticket asks the move to refuse a destination whose surface is wrong for the group. **There is no
terrain data on the Python side at all**: `land.getSurfaceType` is a *runtime* API and only its schema
ships here, and no heightmap or land-type table exists in the repository. So a design-time surface
check would have to invent its answer.

That is not an oversight in the ticket — it is the same wall `FEAT-SCENERY-AWARE-SPAWN` hit, which is
exactly why that lot solved the problem **at runtime**, around DCS's own `Disposition` singleton
(ADR 0018). The design-time cousin the ticket hoped for does not exist yet, and would be a data lot of
its own.

Delivered instead: the move **says** it could not look, in the action's `warnings`, in both catalogue
languages, and in the action description the calling agent reads. A validation that lied would be
worse than an absent one, because a mission maker would stop checking.

## What `add_air_group` turned into

The triage filed it here and flagged the question as unsettled: *"decide that when 03 is picked up,
with the composite in front of you"*. Measured while doing so — a parked unit carries **two** distinct
numbers, `parking` **and** `parking_id` (28 and 24 on the same aircraft in
`test/veaf-tools/test.miz`), matching the runtime's `Term_Index` / `Term_Index_0` — so putting a
two-ship "on the ramp at Incirlik" needs per-airfield slot ids that no data in this repository holds.

David's call (2026-08-12): **do it, with the parking data**, which makes it two tickets rather than a
line in this one — [08](08-capture-parking-data.md) captures the data, [09](09-add-air-group.md)
spends it.

## Tasks

- [x] Move translates all units **and** all waypoints by one delta — plus the group's own `x`/`y`
      anchor, which the ticket did not mention and the editor draws from. The shear test was proven
      discriminating by breaking the translation on purpose and watching exactly those two tests fail.
- [x] Move uses the existing geodesic offset, not naive metre arithmetic — pinned against
      `veaf_libs.coordinates` itself, so the projection cannot be quietly bypassed later.
- [x] Move **warns** rather than refuses on the destination's surface, for the reason above.
- [x] Rename runs the existing convention validation and refuses a name that breaks it, with
      `acknowledge_conventions` for the legitimate case of renaming *into* a convention. Also refuses
      a **collision**, which the ticket did not ask for: two groups sharing a name makes every later
      edit ambiguous, including undoing this one.
- [x] Frequency gated on the aircraft's `HumanRadio` bounds from `dcs-radio-specs.yaml`, reusing the
      presets injector's validator. **Every** unit type in the group is checked, not just the first —
      a mixed group would otherwise pass here and be refused by the editor because of another member.
- [x] Booleans: late activation, hidden, uncontrolled. `None` means "not given" and `False` means
      "off", so a flag can actually be cleared.
- [x] Mission-maker catalogue doc updated in this ticket, plus the developer reference.

## Acceptance criteria

- [ ] 🧑 Round trip through the DCS Mission Editor with no complaint, including a moved group with a
      route. David's to do — no DCS on the workstation this was written on.
- [x] Tests: the shear case (units move, waypoints do not) must fail before the fix and pass after.
      **Verified by sabotage**: dropping the waypoints from the translation made
      `test_the_route_travels_with_the_units` and `test_a_move_to_a_target_still_carries_the_route`
      fail, and nothing else — so they measure the shear rather than the move in general.
- [x] `ruff` / `mypy` / `pytest` green over the whole tree; coverage gate bumped per the ratchet.
