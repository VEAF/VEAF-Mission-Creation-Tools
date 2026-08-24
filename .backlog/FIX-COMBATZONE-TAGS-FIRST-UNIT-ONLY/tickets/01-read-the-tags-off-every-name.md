# 01 — A group's tags are read off every name that carries them

Status: ✅ done
Type: fix

Found on 2026-08-19 while adding `#alarm=` in `FIX-COMBATZONE-CONVOY-ALARM`, opened at David's request.
No GitHub issue: nobody ever reported it, because the symptom is "my tag does not work" on a mission
where it works after moving it to another truck.

## The defect

`VeafCombatZone:initialize` builds one zone element per unit found in the trigger zone, reads the seven
tags off `unitName`, and *then* throws the element away if the group was already registered
([`veafCombatZone.lua:884-978`](../../../src/scripts/veaf/veafCombatZone.lua:884)):

```lua
for _, unit in pairs(units) do
  local zoneElement = VeafCombatZoneElement:new()
  local unitName = unit:getName()
  -- the seven tags are parsed off unitName and applied to zoneElement here
  if not alreadyAddedGroups[groupName] then
    alreadyAddedGroups[groupName] = groupName
    zoneElement:setName(groupName)
  else
    zoneElement = nil -- don't add this element, it's a group that has already been added
  end
end
```

The tags of the second and later units of a group are parsed, applied, and discarded with the element.
Only whichever unit the loop reaches **first** ever has any effect — and that order comes from
`mist.getUnitsInZones` followed by `pairs()`, which promises nothing. Tag one truck of a convoy and the
tag works or does not work depending on an order the mission maker cannot see.

The documentation makes it worse: the page says *"Unit **and group** names in the DCS Mission Editor can
carry special tags"* ([`veafCombatZone.md:214`](../../../doc/mission-maker/scripts/veafCombatZone.md:214)),
but `initialize` only ever looks at `unitName`. A tag on a group name is silently ignored.

## The rule chosen, and why

The PRD left the choice open between reading every name and making the single-unit rule deterministic.
**Reading every name**, because the other option documents the lottery instead of removing it: "the
group's first unit as DCS orders them" is not something a mission maker can look at in the editor, and
making it truly deterministic costs the same sort as reading every name does.

> A group's tags are the tags carried by **its own name and by the names of all its units**. Sources are
> read in a fixed order — the group name first, then the unit names in **alphabetical** order — and the
> first value found for a tag wins.

Alphabetical rather than encounter order on purpose: encounter order is `pairs()`, so a tie-break based
on it would be exactly the coin toss this ticket removes, and a mission maker can see an alphabetical
order in the editor.

**`#command` keeps its current rule and is not merged**, because it is not a setting of the group — it
turns one object into a one-shot trigger that is executed and destroyed. Merging it would silently drop
the second command of a group carrying two, which works today. So:

- a unit carrying `#command` becomes its own element, as it does now;
- a `#command` on the **group** name makes the group one single trigger — which is what the doc has been
  promising all along — rather than one per unit;
- the six settings tags are merged and apply to command elements too, so `#spawndelay` on the group name
  now reaches a `#command` unit that had none.

## Shape

- `veafCombatZone.TAG_PATTERNS` — the seven tags as a table, so a sweep over "all the tags" is
  enumerable instead of seven hand-written `find` calls.
- `veafCombatZone.parseTags(name)` — one name in, a table of raw tag values out. Pure, testable.
- `veafCombatZone.collectTags(names)` — the ordered merge above. Pure, testable.
- `initialize` groups the units it found, collects once per group, and applies.

## Definition of done

- [x] A tag on the second unit of a two-unit group takes effect
- [x] A tag on the group name takes effect
- [x] All six settings tags are covered, not just the one that surfaced it
- [x] `#command` on a group name makes one trigger, not one per unit
- [x] Lua tests on `parseTags`, `collectTags` and on `initialize` end to end
