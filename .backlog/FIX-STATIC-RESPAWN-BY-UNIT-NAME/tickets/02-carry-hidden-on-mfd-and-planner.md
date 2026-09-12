# 02 — Carry hiddenOnMFD and hiddenOnPlanner

Status: ✅ done

## What

The group record carries `hidden` and not its two neighbours. The Mission Editor writes all three
together — Tripack's mission has `hidden`, `hiddenOnMFD` and `hiddenOnPlanner` all true on 446 of its
469 groups — so anything VEAF puts back on the map comes back visible on every datalink display and
in the mission planner, whatever DCS does with `hidden` itself.

Two fields in `veafMissionDb`'s group record, forwarded by the same path `hidden` already takes
(`addGroup` submits the record as it stands; `addStatic` hoists unit fields over it and leaves
group-level ones alone).

No default is invented for them: `nil` when the editor said nothing, exactly as the record does for
`task`, `frequency` and the rest. `addGroup` defaults `hidden` to `false` and that stays its own
business.

## Not in scope, deliberately

`getCurrentGroupData` clears `uncontrolled` and `hidden` for a **teleport**, restored on David's call
on 2026-09-07. These two fields are not added to that clearing: the decision it implements was about
an aircraft arriving unusable and about the F10 map, and nothing measured says a teleported group
should also reappear on a datalink. Changing it would be a behaviour change this lot did not measure.

## Tests

In `test_veafMissionDb.lua`: a group with the three flags set records the three; a group with none
records nil for the three.

In `test_veafDcsSpawner.lua`: a clone and a respawn both submit `hiddenOnMFD` / `hiddenOnPlanner` as
the editor set them.

## Done when

- A respawned group is as hidden as the editor made it, on all three surfaces
- The coverage floor moves with the new tests, per the quality ratchet
