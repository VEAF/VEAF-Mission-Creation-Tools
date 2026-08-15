# 02 — `edit_route add` ignores the altitude and speed it is given

Status: ⬜ ready
Type: fix
Files: `src/python/veaf-tools/veaf_mission_mcp/route_editing.py`, tests

## What happened

```
edit_route(operation="add", name="ATTAQUE", altitude_ft=18000, speed_kt=350)
```

The waypoint was appended with the right name and position, and with **20000 ft / 449 kt** — the
values of the preceding waypoint. The two parameters were accepted, documented in the schema
(*"altitude in FEET and speed in KNOTS … the conversion is done for you"*) and silently dropped.

Found while preparing the 2026-08-15 editor round-trip, before the mission ever reached DCS.

## Why it is worth more than it looks

A caller cannot tell. The action returns the resulting route, so a careful reader sees 20000 where
they asked for 18000 — but the value they get is *plausible*, inherited from the neighbour rather
than absurd, which is the kind of wrong that survives review. A strike waypoint at the transit
altitude is a flight that does the wrong thing, not one that fails.

`set` presumably applies both (that path is what `altitude_ft` was written for). So the fix is likely
to be that `add` and `insert` never call the same code — worth checking `insert` in the same pass
rather than fixing only the operation that was caught.

## TDD

- `add` with `altitude_ft` and `speed_kt` produces exactly those values, converted — the test that
  fails today.
- The same for `insert`.
- A test that `add` **without** them still inherits from the previous waypoint, since that is the
  useful default and must not be broken by the fix.

## Acceptance criteria

- [ ] `add` and `insert` honour `altitude_ft` and `speed_kt`.
- [ ] Inheritance still applies when they are omitted.
- [ ] Full Python gate green; coverage ratchet respected.
