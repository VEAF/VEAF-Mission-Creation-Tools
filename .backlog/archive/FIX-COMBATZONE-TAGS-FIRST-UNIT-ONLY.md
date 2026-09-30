# FIX-COMBATZONE-TAGS-FIRST-UNIT-ONLY — a unit-name tag counts only on the first unit met

Status: ✅ done — shipped in 6.15.14, closed 2026-08-22 on unit coverage · archived 2026-09-28

Written, unit-tested and shipped in 6.15.14. The in-game gate is **withdrawn, not skipped**: the check
that guarded it could not come out either way.

## Why the in-game check was dropped

It said: activate the zone, watch two M-1 Abrams — *they stay put* means the tag on unit #002 reached the
group, *they drive off* means it did not. Run on 2026-08-22, the tanks drove off.

That is not a verdict. `#alarm=2` reduces to `setOption(AI.Option.Ground.id.ALARM_STATE, 2)` in
`veaf.readyForCombat` (`veaf.lua:2117`), reached from `veafCombatZone.lua:1505`. Nothing on that path
immobilises anything. A mobile group with a route drives it under RED exactly as under AUTO — the two
states the check meant to distinguish are **visually identical for this group**, so the observation could
neither fail nor succeed. The criterion came from an untested assumption about DCS, written into a session
plan as if it were behaviour.

What the game would have added over the tests is only "DCS honours the option it was given", which is not
our code and not what this lot changed. What *is* ours — reading a tag off any unit of a group instead of
the first one met — is covered by enumerated tests across the whole tag family with the tag on the
**second** unit (`test/lua/test_veafCombatZone.lua:1674`, `:1872`).

The episode cost more than the check was worth: two waypoints were added to the group on 2026-08-21 purely
to make it possible, and the hand-copied second waypoint is what later made the DCS editor refuse to save
`verify-mission-a` — filed as
[`FIX-VALIDATE-CONTRADICTORY-WAYPOINT-LOCKS`](FIX-VALIDATE-CONTRADICTORY-WAYPOINT-LOCKS.md), since
`mission validate` reported that same file clean. An in-game check earns a session only if it can come out
both ways.

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
| 01 | [A group's tags are read off every name that carries them](FIX-COMBATZONE-TAGS-FIRST-UNIT-ONLY.md) | ✅ |
| 02 | [Two units disagreeing about a tag is reported, not tossed](FIX-COMBATZONE-TAGS-FIRST-UNIT-ONLY.md) | ✅ |
| 03 | [Make the documentation's group-name promise true, and stop the verification mission dodging the case](FIX-COMBATZONE-TAGS-FIRST-UNIT-ONLY.md) | ✅ |

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
[FIX-COMBATZONE-DEAD-SPAWN-RADIUS-DEFAULT](FIX-COMBATZONE-DEAD-SPAWN-RADIUS-DEFAULT.md), and the
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

---

## Tickets, in full

## 01 — A group's tags are read off every name that carries them

Status: ✅ done
Type: fix

Found on 2026-08-19 while adding `#alarm=` in `FIX-COMBATZONE-CONVOY-ALARM`, opened at David's request.
No GitHub issue: nobody ever reported it, because the symptom is "my tag does not work" on a mission
where it works after moving it to another truck.

### The defect

`VeafCombatZone:initialize` builds one zone element per unit found in the trigger zone, reads the seven
tags off `unitName`, and *then* throws the element away if the group was already registered
([`veafCombatZone.lua:884-978`](../../src/scripts/veaf/veafCombatZone.lua:884)):

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
carry special tags"* ([`veafCombatZone.md:214`](../../doc/mission-maker/scripts/veafCombatZone.md:214)),
but `initialize` only ever looks at `unitName`. A tag on a group name is silently ignored.

### The rule chosen, and why

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

### Shape

- `veafCombatZone.TAG_PATTERNS` — the seven tags as a table, so a sweep over "all the tags" is
  enumerable instead of seven hand-written `find` calls.
- `veafCombatZone.parseTags(name)` — one name in, a table of raw tag values out. Pure, testable.
- `veafCombatZone.collectTags(names)` — the ordered merge above. Pure, testable.
- `initialize` groups the units it found, collects once per group, and applies.

### Definition of done

- [x] A tag on the second unit of a two-unit group takes effect
- [x] A tag on the group name takes effect
- [x] All six settings tags are covered, not just the one that surfaced it
- [x] `#command` on a group name makes one trigger, not one per unit
- [x] Lua tests on `parseTags`, `collectTags` and on `initialize` end to end

---

## 02 — Two units disagreeing about a tag is reported, not tossed

Status: ✅ done
Type: fix

Depends on [01](FIX-COMBATZONE-TAGS-FIRST-UNIT-ONLY.md).

### The problem this creates

Reading every name introduces a case that cannot happen today: two units of one group carrying
`#alarm=0` and `#alarm=2`, or a group name saying `#spawnchance=50` while a unit says
`#spawnchance=100`. One of them has to lose.

### The rule

The first source in the fixed order wins — group name, then unit names alphabetically — and every later
source carrying a **different** value for the same tag is ignored with a `warn` naming both values and
where they came from. A later source repeating the *same* value is silent: tagging every truck of a
convoy identically is the ordinary way of doing it and must not produce a log line per truck.

This follows the precedent set by `FIX-COMBATZONE-CONVOY-ALARM`, whose `#alarm=7` fallback was made to
warn for the same reason Sourcery gave then: a fallback nobody is told about makes a mistake look like a
choice.

The existing warning for an unreadable `#alarm` tag (`#alarm=`, `#alarm=x`, `#alarm=-1`) moves to the
collection step and keeps its meaning — it fires when **no** source produced a state and at least one
carried the `#alarm` text.

### Definition of done

- [x] Conflicting values produce one `warn` and the first source's value
- [x] Repeated identical values produce no warning
- [x] The unreadable-`#alarm` warning still fires, and does not fire when another unit of the group
      states a readable one
- [x] Lua tests for all three

---

## 03 — Make the documentation's group-name promise true, and stop the verification mission dodging the case

Status: ✅ done
Type: fix

Depends on [01](FIX-COMBATZONE-TAGS-FIRST-UNIT-ONLY.md).

### Documentation

`doc/mission-maker/scripts/veafCombatZone.md` (and `.en.md`) claim unit **and group** names carry tags,
which was false. Ticket 01 makes it true, so the pages need the rule stated rather than the claim left
implicit:

- where the tags are read from, and the fixed source order;
- what happens when two names disagree;
- that `#command` stays attached to the object carrying it, and what a `#command` on a group name means.

### Verification mission

`test/veaf-tools/verify-mission-a` set its `#alarm=2` check up by tagging **both** M-1 Abrams of the
group, precisely to dodge this defect — so the in-game pass on 2026-08-18 proved nothing about the
single-unit case. Re-tag one Abrams only, so the mission proves the case instead of avoiding it.

### Definition of done

- [x] Both language pages state the rule, the source order and the conflict behaviour
- [x] `poetry run docs-check` passes
- [x] `verify-mission-a` carries `#alarm=2` on exactly one of the two Abrams
- [x] The mission's README says what the check now proves

---
