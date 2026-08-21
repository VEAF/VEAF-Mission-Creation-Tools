# FEAT-GROUP-COMBAT-INEFFECTIVE — decide when a group has stopped being a threat

Status: ✅ done — shipped in 6.15.24

Origin: [#177](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/177), 2023, with a proposed
config table in the issue body.

## The idea

A group is not only alive or dead. An S-300 whose tracking radar is destroyed still has launchers and
crew, and counts as alive everywhere in our code — while in play it is finished. The issue proposes
declaring, per group pattern, which units are the **important** ones and what minimum life they need,
defaulting to what DCS's own unit description says (`"SAM TR"` = important).

## Why it is the most structural of the small lots

Three places currently ask "is this group still a problem?" and each answers it its own way:

- `veafCombatZone:completionCheck()` counts **units of the hostile side**, so a toothless SAM keeps a
  zone open
- Skynet decides whether a site is worth defending
- the F10 reports tell a player what is left

One shared predicate would serve all three. Which is also the risk: changing what "alive" means
changes when zones complete. Ship the predicate first and adopt it caller by caller, not in one pass.

## Scope

- a `veaf.isGroupCombatEffective(group)` style predicate, with the pattern/importance table from the
  issue, defaulting to the DCS attributes
- adopted by **one** caller to prove it, chosen with David — `completionCheck` is the visible one and
  therefore the riskiest
- Lua tests on a partially destroyed S-300

## What shipped

`veaf.isGroupCombatEffective(groupOrName)`, in `veaf.lua` next to `veaf.getUnitLifeRelative`. Two paths:

1. **A pattern** in `veaf.ImportantUnitsByGroupPattern` matches the group name. The group is effective
   only while **every** declared set still has a member above `minimumLife`. The S-300 entry from the
   issue body ships as the first pattern.
2. **No pattern**: the DCS attributes decide. A group with a living `SAM SR` or `SAM LL` *is* a SAM site
   and is finished once nothing living carries `SAM TR`. Anything else is a problem while anything of it
   lives.

Attributes come from `dcsUnits.DcsUnitsDatabase[type].attribute` — the repository's own generated
database — not from `Unit.getDesc()`. Same data, no DCS call, and a type can be asked about without a
living unit to ask through, which is what makes the whole thing testable.

`minimumLife` is a **percentage**, compared through `veaf.getUnitLifeRelative`. Absolute hit points
would mean a different threshold per unit type, which no mission maker can reason about.

### The limit, stated rather than hidden

Dead units vanish from `Group:getUnits()`, so the predicate cannot know a group *had* a radar it has
since lost. **The pattern table is what carries that knowledge** — a pattern asserts the group owns
those sets. The default cannot, so a SAM site stripped of both its radars *and* its launchers reads as
an ordinary group. By then nothing dangerous is left of it, which is why that is acceptable rather than
merely tolerated.

A related simplification worth recording: the predicate does **not** re-filter `getUnits()` through
`veaf.isUnitAlive`. DCS already drops a destroyed unit from its group, so that list *is* the survivors —
and filtering it imposed an `isExist`/`isActive` requirement that broke four existing tests whose unit
stubs, quite reasonably, did not implement them.

## The first adopter: the F10 report

The PRD warned that `completionCheck` is *"the visible one and therefore the riskiest"*. So the first
adopter is the **zone report**, which **adds** information and removes none:

```
OUT OF ACTION (can no longer fight): REPORTZONE-SA10
```

No mission behaviour changes — which is exactly the promise a first adopter should be able to make. A
group with nothing left is reported as destroyed by the existing tallies, not as out of action: the
predicate answers false for both, so the report tells them apart by checking for survivors itself.

## What adopting it elsewhere would change, for a player

### `completionCheck` — the one worth doing next, and the one that needs a decision

Today it counts **units of the hostile coalition**; a zone completes when that count reaches zero. With
the predicate, it would count only units belonging to groups that are still effective.

| | Today | With the predicate |
|---|---|---|
| A player kills an S-300's tracking radar and leaves | zone stays open; he must hunt every launcher and truck | zone completes |
| A zone holding a SAM site **and** a convoy | completes when both are gone | completes when the convoy is gone and the SAM is toothless |
| A zone whose SAM is toothless but intact | stays open | **completes with units still alive and visible in it** |

That last row is the risk, and it is a design question rather than a technical one: a zone announcing
"all enemies destroyed" while a player can see four launchers is either a welcome shortcut or a bug,
depending on what the mission maker meant. It also changes **every existing mission** that holds a SAM
site. Worth its own lot, with the choice put to David rather than assumed — plausibly as a per-zone
switch, following the convention `FIX-COMBATZONE-RENAME-OPTION` established.

### Skynet — smaller, and safe

`veafSkynet.findSkynetElementToDefend` (`veafSkynetIadsHelper.lua:404`) picks which site a point-defence
group protects. With the predicate it would skip sites that can no longer fight, so a Tor does not spend
the mission guarding a decapitated S-300 while a live one goes undefended.

For a player this is invisible until it matters, and it cannot end a mission early — which makes it the
safer second adopter, and a better one than `completionCheck` if the appetite is for another
no-behaviour-change step.

**Filed as `FEAT-COMBAT-EFFECTIVE-ADOPTION`** rather than left in this PRD.

## Definition of done

- [x] The predicate exists, table-driven, with the DCS-attribute default
- [x] One caller adopts it, and which one is recorded here — the F10 report, because it changes no
      behaviour
- [x] The other callers listed with what adopting would change for a player — both, with the risky row
      of `completionCheck` called out as a design question rather than a technical one
