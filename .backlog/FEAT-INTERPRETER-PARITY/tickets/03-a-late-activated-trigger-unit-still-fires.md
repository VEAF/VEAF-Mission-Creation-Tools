# 03 — A trigger unit the world does not hand back still fires

Status: ✅ done
Type: fix

## What #123 is really asking

`#veafInterpreter["…"]` on a unit name makes that unit a one-shot trigger: the interpreter runs the
command at its position and destroys it. A mission maker naturally wants that unit **out of the way** —
late-activated, so it never exists in the world at all.

`executeCommandOnUnit` reads the position from the **running world**:

```lua
local unit = Unit.getByName(unitName)
if unit then … else local static = StaticObject.getByName(unitName) …
```

A unit the world does not hand back reaches neither branch, and the command is dropped **in silence**.
A late-activated unit is the obvious case; a unit destroyed in the first second of the mission is
another.

## The fix, and why it does not depend on knowing DCS's answer

`_initialize` already walks `mist.DBs.units` and holds the mission record of every unit — including
`x`, `y`, `alt`, `coalitionId` and `groupName`. Whether or not `Unit.getByName` resolves a
late-activated unit (which cannot be settled from a workstation), passing that record down as a
**fallback** makes the trigger fire either way. The dependency is removed rather than understood.

Coordinates need care and `docs/agents/dcs-coordinates.md` is the reason: a mission record's `y` is the
**easting**, while the runtime position the command expects is a vec3 whose `y` is the altitude.
`veaf.placePointOnLand` takes exactly the first shape and returns the second, so no conversion is
hand-written.

Nothing is destroyed on that path: there is no world object to destroy.

## Definition of done

- [x] A trigger the world does not hand back still runs its command, at the position the mission gives
- [x] It is not destroyed, and does not raise trying
- [x] The existing paths (live unit, static) are untouched
- [x] Lua tests for all three, including the coordinate conversion
