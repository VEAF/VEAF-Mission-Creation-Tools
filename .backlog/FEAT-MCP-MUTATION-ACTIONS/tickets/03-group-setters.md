# 03 — Group setters

Status: ⬜ ready
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

## Tasks

- [ ] Move translates all units **and** all waypoints by one delta; test proves the formation and the
      route stay attached.
- [ ] Move uses the existing geodesic offset, not naive metre arithmetic.
- [ ] Move refuses (or warns, per 01's decision) a destination whose surface is wrong for the group.
- [ ] Rename runs the existing convention validation and refuses a name that breaks it.
- [ ] Frequency gated on the aircraft's `HumanRadio` bounds from `dcs-radio-specs.yaml`.
- [ ] Booleans: late activation, hidden, uncontrolled.
- [ ] Mission-maker catalogue doc updated in this ticket.

## Acceptance criteria

- [ ] Round trip through the DCS Mission Editor with no complaint, including a moved group with a route.
- [ ] Tests: the shear case (units move, waypoints do not) must fail before the fix and pass after.
- [ ] `ruff` / `mypy` / `pytest` green over the whole tree; coverage gate bumped per the ratchet.
