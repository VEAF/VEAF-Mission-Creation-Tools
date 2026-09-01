# FIX-GETGROUPDATA-SKIPS-NEUTRALS — half the CAP templates are unreachable, and the error blames the wrong thing

Status: ⬜ ready

Found in game 2026-09-01: `-cap` and `-cap mig29` both failed with
`spawnCombatAirPatrol: could not find a template for mig29`.

## The defect

`veaf.getGroupData` (`veaf.lua:2435`) walks the mission by hand and enters only two coalitions:

```lua
for coa_name, coa_data in pairs(env.mission.coalition) do
  if (coa_name == "red" or coa_name == "blue") and type(coa_data) == "table" then
```

**`neutrals` is never entered.** Measured on the session mission's 117 `veafSpawn-` templates:

| Coalition | Templates | |
|---|---|---|
| blue | 20 | reachable |
| red | 36 | reachable |
| **neutrals** | **61** | **invisible** |

**56 of 117 work.** All fourteen MiG-29 templates are neutral, which is why that name failed while
others would have succeeded.

## Why the log accuses the wrong thing

`spawnCombatAirPatrol` asks for two values:

```lua
local chosenTemplateName, chosenTemplateData = veafSpawn.findSpawnableAircraftGroupname(name)
if not chosenTemplateName or not chosenTemplateData then
  ... "could not find a template for %s" ... veaf.p(name)
```

The name **was** found — `findSpawnableAircraftGroupname` matched it against
`veafSpawn.airUnitTemplates` and chose one. It is the *data* lookup that returns nil. But the message
prints `name` — what the pilot typed — not `chosenTemplateName`, so it reads as *"that aircraft does
not exist"* when the truth is *"I found it and could not read it"*.

That is why this survived: the message sends every investigation to the wrong place.

## And why it looked intermittent

`-cap` with no name draws at random from all 117 templates, so it fails **roughly one time in two**,
with no pattern a user could report. *"It has always worked"* and *"it does not work"* are both true
accounts of the same defect.

## The fix is already half-written next door

`veafMissionDb.buildSnapshot` (`veafMissionDb.lua:146`) indexes **every** coalition — no filter. And
`veaf.getGroupData` already calls `veaf.getGroupRecord` on its first line to resolve the id, then
**throws that away and re-walks the mission by hand**. Routing it through the index removes the
filter and the duplication at once.

This is a leftover the `DROP-MIST` campaign did not sweep: the index it built is the answer, and one
caller never moved onto it.

## Not a regression from this week

Established, since it was the first hypothesis: the `red or blue` filter dates from **2026-03-14**,
and `findSpawnableAircraftGroupname`'s call to `veaf.getGroupData` from **2026-05-21**. Both predate
`DROP-MIST`. The three functions on the lookup path are byte-identical between the 2026-08-28 build
and today's, as are the 117 template groups, field by field.

## Definition of done

- [ ] `veaf.getGroupData` finds a group whatever coalition holds it, neutral included
- [ ] It goes through `veafMissionDb` rather than re-walking `env.mission` — one index, one answer
- [ ] **Every other hand-rolled walk of `env.mission.coalition` enumerated** and either routed through
      the index or shown to be correct; `veaf.lua:2435` was the only `red or blue` filter found, but
      that search was one pattern, not an enumeration
- [ ] The error message names the template it rejected, not the string the user typed — a message
      that states the wrong cause is worse than no message
- [ ] A test drives a **neutral** group through `getGroupData`, and it fails before the fix
- [ ] A test asserts the CAP error message contains the chosen template name

## Worth checking in the same pass

Whether anything else asks for `chosenTemplateData` and silently drops a template it had found.
