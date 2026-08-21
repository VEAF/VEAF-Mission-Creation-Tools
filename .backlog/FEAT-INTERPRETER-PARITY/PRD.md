# FEAT-INTERPRETER-PARITY — interpreter units cannot be randomised, hidden or late-activated

Status: ✅ done — shipped in 6.15.23

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
