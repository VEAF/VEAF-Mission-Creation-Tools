# FIX-COMBATZONE-TAGS-FIRST-UNIT-ONLY — a unit-name tag counts only on the first unit met

Status: ⬜ ready

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

## What this lot has to decide

- **Which names are read.** The obvious shape: gather the tags from *every* unit of the group **and**
  from the group name, so any of them works. Then a conflict rule is needed — two units of one group
  carrying `#alarm=0` and `#alarm=2`. Suggested: last one wins is arbitrary; **warn and keep the
  first** is honest, and this repository now has the `warn`-on-ambiguity precedent from the `#alarm`
  fallback.
- **Or the opposite**: keep reading one unit only, but make it *deterministic and documented* (the
  group's first unit as DCS orders them), and fix the doc. Cheaper, and arguably clearer than "any
  unit, and here is the tie-break".
- Either way the doc's "and group names" claim gets made true or removed.

## Definition of done

- [ ] A tag on any unit of a multi-unit group takes effect — or the rule is deterministic, documented
      and the doc's group-name claim corrected
- [ ] Conflicting tags within one group produce a warning rather than a coin toss
- [ ] Lua tests covering a two-unit group tagged on the second unit, and a tag conflict
- [ ] Applies to all seven tags (`#command`, `#spawngroup`, `#spawnradius`, `#spawncount`,
      `#spawnchance`, `#spawndelay`, `#alarm`), not just the one that surfaced it
- [ ] `verify-mission-a` re-tagged on a single Abrams once fixed, so the mission proves the case
      instead of dodging it
