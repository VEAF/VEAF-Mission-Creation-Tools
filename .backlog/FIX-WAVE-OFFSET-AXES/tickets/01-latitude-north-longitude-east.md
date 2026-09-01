# 01 — Put each delta on the axis its name names

Status: ✅ done

Type: fix · Files: `src/scripts/veaf/veafAirWaves.lua`, `src/scripts/veaf/veafQraCore.lua`,
`test/lua/test_veafAirWaves.lua`, `test/lua/test_veafQraManager.lua`,
`test/python/test_wave_offset_axes.py`

## The defect

Four sites — the VEAF command branch and the DCS group branch of each module — read:

```lua
local position = { x = zoneCenter.x - lonDelta, y = zoneCenter.y, z = zoneCenter.z + latDelta }
```

`x` is the northing and `z` the easting, so `latDelta` moved the spawn **east** and `lonDelta` moved
it **south**. Both parameters of the public `setRespawnDefaultOffset(defaultOffsetLatitude,
defaultOffsetLongitude)` meant something other than their names, `@param` tags included, and the
northing was subtracted on top — a positive latitude offset moved *away* from the pole.

## What was done

All four sites now read `x = zoneCenter.x + latDelta, z = zoneCenter.z + lonDelta`, with the old form
and the reason quoted in a comment at the command branch of each module so the next reader does not
have to find this ticket.

Tests in two layers:

1. **Lua, behaviour.** Five cases on `veafAirWaves`, three on `veafQraCore`. Each drives one axis at a
   time with a distinct non-zero value and asserts the **delta from the zone centre**, not the
   absolute field: an assertion on `position.x` would survive a future rename of the two locals,
   while an assertion on the delta only survives if the *axes* are right. `respawnRadius` is zeroed so
   the scatter cannot blur the measurement, and one case covers the public setter rather than the
   bracket prefix, because they feed the same two fields.
2. **Python, source.** `test_wave_offset_axes.py` refuses a delta paired with the wrong axis, or
   subtracted, anywhere in either module — plus an assertion that four such assignments still exist,
   so a rename cannot leave the check green on a file it no longer understands.

## Why the second layer

The DCS-group branch only reaches its offset **when DCS fails to return a group's units**. Driving
that from a unit test means faking a group record with no units and intercepting the spawn chain; it
is the path least likely to be exercised, and therefore the one where half a repair survives.

Measured: reverting that fourth site alone leaves **all 45 Lua suites green** and turns the source
test red, naming `veafQraCore.lua:1026` and the reason. Without this layer the repair could have
shipped half-done, green.

## Proof it can fail

| Sabotage | Result |
|---|---|
| original formula restored in `veafAirWaves` | 5 Lua tests red |
| original formula restored in `veafQraCore` only | 3 Lua tests red, `veafAirWaves` staying green |
| QRA DCS-group branch alone reverted | Lua all green, source test red at `veafQraCore.lua:1026` |
