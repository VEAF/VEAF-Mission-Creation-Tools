# FIX-COMBATZONE-TAGS-FIRST-UNIT-ONLY — a unit-name tag counts only on the first unit met

Status: 🧑 waiting-human

Written, unit-tested and shipped in 6.15.14. Waiting on one in-game look at `verify-mission-a`, which
needs DCS started — see [DCS-SESSION-TODO.md](../../DCS-SESSION-TODO.md).

Origin: found on 2026-08-19 while adding `#alarm=` in `FIX-COMBATZONE-CONVOY-ALARM`, and opened at
David's request. Affects **all seven** combat-zone tags, not the new one.

## What the code does

`VeafCombatZone:initialize` iterates the units found inside the trigger zone and builds one zone
element per **group** (`veafCombatZone.lua:815-889`):

```lua
for _, unit in pairs(units) do
  local zoneElement = VeafCombatZoneElement:new()
  ...
  -- the seven tags are read off unitName here and applied to zoneElement
  ...
  if not alreadyAddedGroups[groupName] then
    alreadyAddedGroups[groupName] = groupName
    zoneElement:setName(groupName)
  else
    zoneElement = nil -- don't add this element, it's a group that has already been added
  end
end
```

So for the second and later units of a group, the tags **are** parsed and applied — to a
`zoneElement` that is then thrown away. Only the tags carried by whichever unit of the group the loop
reaches **first** ever take effect.

## Why that is not a theoretical problem

The order comes from `findUnitsInCombatZone` → `mist.getUnitsInZones`, then `pairs()`. Nothing in that
chain promises the mission-editor order, and `pairs()` promises nothing at all. A mission maker who
tags "the convoy" by editing one truck has no way to know which truck the runtime will consider first,
and the tag works or does not work depending on it.

Measured on 2026-08-19: the `#alarm=2` verification on `verify-mission-a` was set up by tagging
**both** M-1 Abrams precisely to dodge this, so the in-game pass does not prove the single-unit case
works.

The documentation makes it worse: the page says *"Unit **and group** names in the DCS Mission Editor
can carry special tags"* (`doc/mission-maker/scripts/veafCombatZone.md:212`), but `initialize` only
ever reads `unitName`. A tag on the group name is silently ignored. So the doc promises two things
that are not true — group names, and any unit of the group.

## Tickets

| # | Ticket | Status |
|---|--------|--------|
| 01 | [A group's tags are read off every name that carries them](tickets/01-read-the-tags-off-every-name.md) | ✅ |
| 02 | [Two units disagreeing about a tag is reported, not tossed](tickets/02-a-conflict-is-reported-not-tossed.md) | ✅ |
| 03 | [Make the documentation's group-name promise true, and stop the verification mission dodging the case](tickets/03-make-the-doc-true-and-retag-the-mission.md) | ✅ |

## The decision taken

**Read every name.** The alternative — one unit only, but deterministic and documented — was rejected
because "the group's first unit as DCS orders them" is not visible in the mission editor, so it
documents the lottery rather than removing it, for the same implementation cost.

> A group's tags are the tags carried by its own name and by the names of all its units. Sources are read
> group name first, then unit names in **alphabetical** order, and the first value found for a tag wins.
> A later source stating a different value is ignored with a warning.

Alphabetical, not encounter order: the encounter order *is* `pairs()`, so tie-breaking on it would
reinstate the coin toss.

`#command` is excluded from the merge and keeps its current rule — it is a one-shot trigger attached to an
object, not a setting of the group, and merging it would silently drop the second command of a group
carrying two. A `#command` on a **group** name now makes that group one single trigger, which honours the
documentation's claim without duplicating the command per unit.

## What this lot had to decide

- **Which names are read.** The obvious shape: gather the tags from *every* unit of the group **and**
  from the group name, so any of them works. Then a conflict rule is needed — two units of one group
  carrying `#alarm=0` and `#alarm=2`. Suggested: last one wins is arbitrary; **warn and keep the
  first** is honest, and this repository now has the `warn`-on-ambiguity precedent from the `#alarm`
  fallback.
- **Or the opposite**: keep reading one unit only, but make it *deterministic and documented* (the
  group's first unit as DCS orders them), and fix the doc. Cheaper, and arguably clearer than "any
  unit, and here is the tie-break".
- Either way the doc's "and group names" claim gets made true or removed.

## Two things the implementation turned up

**The verification mission could not have shown the fix, even re-tagged.** `SmokeZone-SmokeArmor` had a
single waypoint, so `FIX-COMBATZONE-ALARM-BY-NATURE` already gives it RED by default and `#alarm=2` was
indistinguishable from no tag at all. Moving the tag to one Abrams would have proved nothing. The group
was given a **second waypoint**, which makes its nature-based default AUTO — so RED can now only come
from the tag, and "the tanks stay put" is a real verdict.

**The 50 m default spawn dispersion has been dead since 2023.** An element starts at `spawnRadius = 0`
and the guard applying the per-category default reads `if not element:getSpawnRadius()`, which is false
for 0 in Lua. `DefaultSpawnRadiusForUnits = 50` is unreachable and every group a combat zone spawns
appears exactly on its recorded position. Out of scope here — the fix is one line but it moves every
existing mission's zone groups — so it is filed as
[FIX-COMBATZONE-DEAD-SPAWN-RADIUS-DEFAULT](../FIX-COMBATZONE-DEAD-SPAWN-RADIUS-DEFAULT/PRD.md), and the
Lua test pins today's behaviour with a pointer to that lot.

## Definition of done

- [x] A tag on any unit of a multi-unit group takes effect — or the rule is deterministic, documented
      and the doc's group-name claim corrected
- [x] Conflicting tags within one group produce a warning rather than a coin toss
- [x] Lua tests covering a two-unit group tagged on the second unit, and a tag conflict
- [x] Applies to all seven tags (`#command`, `#spawngroup`, `#spawnradius`, `#spawncount`,
      `#spawnchance`, `#spawndelay`, `#alarm`), not just the one that surfaced it
- [x] `verify-mission-a` re-tagged on a single Abrams, and given a route so the tag is observable
- [ ] Looked at in game: activate `SmokeZone` and the two Abrams must stay put
