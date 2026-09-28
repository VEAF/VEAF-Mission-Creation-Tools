# FEAT-INTERPRETER-PARITY — interpreter units cannot be randomised, hidden or late-activated

Status: ✅ done — shipped in 6.15.23 · archived 2026-09-28

Origin: [#25](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/25) and
[#123](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/123) — same file, same absence,
grouped for that reason.

## The gap

`veafInterpreter.lua` contains neither `randomiz`, nor `hidden`, nor `lateActivation`: zero
occurrences of all three.

- **#25** — the randomisable parameters (`veaf.getRandomizableNumeric`, `veaf.lua:3237`) never reach
  interpreter or combat-zone elements.
- **#123** — an interpreter unit cannot be late-activated or hidden on the MFD, which the Mission
  Editor offers on any unit.

## Scope

Attribute plumbing rather than new behaviour: the randomiser exists, and `hiddenOnMFD` is already
threaded through `doSpawnGroup`. The work is exposing them where the interpreter reads its
definitions.

Answer here rather than assume: **do combat-zone elements share that path?** #25 names both, and if
they do, one change covers two surfaces.

## The question answered, and half the lot was already built

**#25, interpreter side: already delivered**, by `REFACTOR-MARKER-PARSER`. An interpreter command *is* a
marker command — `veafInterpreter.execute` hands it to `veafCommands.execute` — and
`veaf.markerRules.number` converts through **`veaf.getRandomizableNumeric`** (`veaf.lua:3279`), the very
function the issue pointed at. `#veafInterpreter["_spawn group, name x, size 3-8"]` has been drawing a
size for some time. Nothing to build; a test now says so, because a later refactor could quietly swap
`_num` for `safeNumber` and nobody would notice.

**#25, combat-zone side: not delivered, and worse than unsupported.** Tags are not marker commands.
`TAG_PATTERNS` captured `(%d+)`, so `#spawnradius=100-300` matched **`100`** and the `-300` was never
seen: a mission maker who wrote a range got its lower bound and no warning.

**#123, hidden: nothing to do.** `hiddenOnMFD` is a mission-editor property of the trigger unit. The
interpreter reads a name and a position and neither reads nor writes that flag, so the box can be ticked
today.

**#123, late activation: a real gap.** `executeCommandOnUnit` read the position from the running world
only, so a unit the world does not hand back reached neither of its two branches and its command was
dropped **in silence**.

## A defect found on the way, and it was not new

Widening the tag patterns exposed a crash in `veaf.getRandomizableNumeric` itself: with no upper bound,
the fallback is `MAX = 99`, so `100-` reaches `math.random(100, 99)` — *"interval is empty"*, a raised
Lua error. Reachable **today** from any marker command that takes a number:

```
_spawn group, name x, size 100-      →  bad argument #2 to 'random' (interval is empty)
```

Fixed at the source rather than guarded around: an upper bound below the lower one now means the lower
one, with a warning. Same family as `FIX-MARKER-PARAM-CRASHES` and its sequel. Found by enumerating the
degenerate forms the widened pattern can capture (`-`, `--`, `100-`, `3-1`, …) rather than by sampling a
few.

## Design calls

- **The draw happens when tags are read**, i.e. once per mission at `initialize`. Every activation of a
  zone then uses the same value. Redrawing per activation is a different feature, and a surprising one
  for a dispersion radius.
- **`alarmState` takes no range.** It is an enumeration; `#alarm=0-2` is a typo, not a random state.
- **The late-activation fix does not depend on knowing DCS's answer.** Whether `Unit.getByName` resolves
  a late-activated unit cannot be settled from a workstation, so the mission record `_initialize` already
  holds is passed down as a fallback. The trigger fires either way.

## Definition of done

- [x] An interpreter unit accepts a randomisable numeric where a fixed one works today — it already did;
      proven by test, and the reason recorded
- [x] An interpreter unit can be late-activated and hidden on the MFD — late activation fixed, hidden
      needed nothing, both documented
- [x] The combat-zone-element question answered in writing — and acted on: the tags now take ranges

---

## Tickets, in full

## 01 — The question answered, and the half that was already built

Status: ✅ done
Type: doc

The PRD says *"answer here rather than assume: do combat-zone elements share that path?"*. Answering it
first, because it decides what the other tickets have to do.

### #25 — randomisable numerics

**Already done for the interpreter, by `REFACTOR-MARKER-PARSER`.** An interpreter command is a marker
command: `veafInterpreter.execute` hands it to `veafCommands.execute`, which parses it with the shared
marker rules, and `veaf.markerRules.number` converts through **`veaf.getRandomizableNumeric`**
(`veaf.lua:3279`) — the very function #25 pointed at. So `#veafInterpreter["_spawn group, name x, size
3-8"]` already draws a size between 3 and 8. Nothing to build; something to prove with a test.

**Not done for combat-zone *tags*.** They are not marker commands. `veafCombatZone.TAG_PATTERNS`
captures `(%d+)`, so `#spawnradius=100-300` matches **`100`** and the `-300` is dropped with no warning:
the mission maker gets the lower bound and is never told. That is where #25 still has work, and it is
worse than "unsupported" — it is silently truncated.

### #123 — late activation and hidden

**Hidden needs nothing.** `hiddenOnMFD` is a mission-editor property of the trigger unit. The
interpreter reads a name and a position; it neither reads nor writes that flag, so a mission maker can
tick the box today and the trigger still fires.

**Late activation is a real gap**, and ticket 03 covers it.

### Definition of done

- [x] A test proves an interpreter command accepts a randomisable numeric
- [x] The combat-zone answer recorded in the PRD, both halves

---

## 02 — A combat-zone numeric tag accepts a range instead of truncating it

Status: ✅ done
Type: feat

### The defect

`veafCombatZone.TAG_PATTERNS` reads numeric tags with `(%d+)`:

```lua
spawnRadius = "#spawnradius%s*=%s*(%d+)",
```

On `#spawnradius=100-300` that captures `100`. The `-300` is not rejected — it is **not seen**, so the
mission maker who wrote a range gets the lower bound and no warning. #25 asked for the randomisable
parameters to reach combat-zone elements; they cannot even be written today.

### Scope

The four tags whose value is a count or a distance: `spawnRadius`, `spawnChance`, `spawnCount`,
`spawnDelay`. Conversion goes through `veaf.getRandomizableNumeric`, the same function marker commands
use, so `100-300` means the same thing in both places.

**`alarmState` is deliberately excluded**: it is an enumeration (0 AUTO, 1 GREEN, 2 RED), and a range
over an enumeration is not a random value, it is a mistake. `spawnGroup` is a string.

**When the draw happens** has to be decided rather than fallen into: at tag-reading time, which is
`initialize`, so a range is drawn **once per mission** and every activation of the zone uses the same
value. The alternative — redrawing on each activation — is a different feature and a surprising one for
`spawnRadius`.

### Definition of done

- [x] `#spawnradius=100-300` draws a value in that range, and a plain `#spawnradius=200` is unchanged
- [x] `alarmState` still refuses a range, and says so as it already does for an out-of-bounds value
- [x] Lua tests over each of the four tags, plus the two exclusions
- [x] Documented on the `veafCombatZone` page, both languages

---

## 03 — A trigger unit the world does not hand back still fires

Status: ✅ done
Type: fix

### What #123 is really asking

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

### The fix, and why it does not depend on knowing DCS's answer

`_initialize` already walks `mist.DBs.units` and holds the mission record of every unit — including
`x`, `y`, `alt`, `coalitionId` and `groupName`. Whether or not `Unit.getByName` resolves a
late-activated unit (which cannot be settled from a workstation), passing that record down as a
**fallback** makes the trigger fire either way. The dependency is removed rather than understood.

Coordinates need care and `docs/agents/dcs-coordinates.md` is the reason: a mission record's `y` is the
**easting**, while the runtime position the command expects is a vec3 whose `y` is the altitude.
`veaf.placePointOnLand` takes exactly the first shape and returns the second, so no conversion is
hand-written.

Nothing is destroyed on that path: there is no world object to destroy.

### Definition of done

- [x] A trigger the world does not hand back still runs its command, at the position the mission gives
- [x] It is not destroyed, and does not raise trying
- [x] The existing paths (live unit, static) are untouched
- [x] Lua tests for all three, including the coordinate conversion

---
