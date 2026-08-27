# 01 — Wire the Full Combat Group spawn through findSpawnPoint

Status: ⬜ ready
Type: fix

## What exists

[`veafSpawnGround.lua:594`](../../../src/scripts/veaf/veafSpawnGround.lua) places a *"Full Combat
Group"* — real ground combat units — like this:

```lua
local spawnSpot = veaf.placePointOnLand(mist.getRandPointInCircle(spawnSpot, radius))
```

A raw draw, then a vertical correction. `veaf.placePointOnLand` sets `y` to the ground height and returns:
it does **not** test land versus water and knows nothing about buildings. So a `radius` in wooded or
built-up terrain can drop the whole group inside scenery, with no error and no log.

The four sibling spawners in the same file — lines 387, 441, 483 and 538 — already call
`veaf.findSpawnPoint`, as does the generic `veafSpawnCore.lua:698`. `FEAT-SCENERY-AWARE-SPAWN` wired
*"the four dynamic ground spawners plus the generic `doSpawnGroup`"*; this one was simply not among them.

## What this ticket does

```lua
local spawnSpot = veaf.findSpawnPoint(spawnSpot, radius)
```

Match the four siblings exactly, including how they handle a `nil` return — tier 3 means *nothing
acceptable anywhere*, and the caller is expected to report it and abort the spawn rather than place the
group anyway. Read one of the four and copy its failure path; do not invent a second convention.

**Aborting is right here, and it is measured rather than assumed.** `spawnFullCombatGroup` has exactly
one caller, [`veafSpawnGround.lua:1274`](../../../src/scripts/veaf/veafSpawnGround.lua), and it is
`veafSpawn.registerCommandHandler("fullCombatGroup", "KNOWN_PILOT", …)` acting on an `eventPos` — a
**runtime marker command**, with a user standing there who can read the report and move the marker. That
puts it on the spawn side of David's ruling 3, unlike ticket 02's combat zone elements, which are editor
content and must fall back instead. The `czName` option is only used to name the group; it does not make
this a combat-zone path.

**`radius == 0` must stay exact.** `findSpawnPoint` already guarantees this — its tier 1 is skipped when
`radius` is falsy or zero, with the comment *"A zero radius means 'exactly here, the mission maker means
it'"* — but assert it in a test, because this is the property a mission maker notices breaking.

## Definition of done

- [ ] `veafSpawnGround.lua:594` calls `veaf.findSpawnPoint`, with the same nil-handling as lines 387,
      441, 483 and 538
- [ ] A `nil` return aborts the spawn and reports it; the group is never placed on a rejected point
- [ ] Lua tests: a clear spot is unchanged, `radius == 0` returns the exact point, a spot where every
      candidate is rejected aborts with a report
- [ ] `stylua --check` and `luacheck` clean
