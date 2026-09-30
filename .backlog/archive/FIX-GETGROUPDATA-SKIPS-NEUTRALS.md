# FIX-GETGROUPDATA-SKIPS-NEUTRALS — half the CAP templates are unreachable, and the error blames the wrong thing

Status: ✅ done · archived 2026-09-28

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

### Confirmed in game, by the discriminating pair

Same session, 2026-09-01: `-cap f15` **worked** while `-cap mig29` was refused.

| Command | Templates | Coalition | Result |
|---|---|---|---|
| `-cap f15` | 4 | all **blue** | reached by `getGroupData` → spawned |
| `-cap mig29` | 14 | all **neutrals** | never entered → `chosenTemplateData` nil → rejected |

The name is matched in both cases; only the data read differs. That excludes the template table, the
search pattern and the marker parser in one measurement — it is the `red or blue` filter and nothing
else.

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

## Scope

| # | Ticket | Type | Status |
|---|--------|------|--------|
| 01 | [Route `getGroupData` through the mission index](FIX-GETGROUPDATA-SKIPS-NEUTRALS.md) | fix | ✅ |
| 02 | [The CAP refusal must name the template it rejected](FIX-GETGROUPDATA-SKIPS-NEUTRALS.md) | fix | ✅ |

## Definition of done

- [x] `veaf.getGroupData` finds a group whatever coalition holds it, neutral included
- [x] It goes through `veafMissionDb` rather than re-walking `env.mission` — one index, one answer
- [x] **Every other hand-rolled walk of `env.mission.coalition` enumerated** and either routed through
      the index or shown to be correct; `veaf.lua:2435` was the only `red or blue` filter found, but
      that search was one pattern, not an enumeration
- [x] The error message names the template it rejected, not the string the user typed — a message
      that states the wrong cause is worse than no message
- [x] A test drives a **neutral** group through `getGroupData`, and it fails before the fix
- [x] A test asserts the CAP error message contains the chosen template name

## What the enumeration found

Three reads of `env.mission.coalition` in `src/scripts/veaf/`, no more: the walk that is fixed here,
`buildSnapshot`'s own walk (no filter, correct, and now the only one), and `getBullseye`'s keyed
read (no walk, correct). Full table in ticket 01.

It also turned up **a second neutral defect one floor down**, inside the index this lot makes
authoritative: the mission file spells the side `neutrals` and `coalition.side` spells it `NEUTRAL`,
so every neutral record was indexed with `coalitionId = nil`. Fixed in ticket 01.

And one **adjacent** site that is not an `env.mission` walk, left for David: `refreshDynamicSlots`
sweeps `{ RED, BLUE }` of the runtime API and is the only coalition sweep in the module tree that
omits `NEUTRAL`. Editor-declared neutral slots are already covered; whether DCS ever creates a
*dynamic* neutral slot cannot be settled without the game.

## Worth checking in the same pass

Whether anything else asks for `chosenTemplateData` and silently drops a template it had found.
Checked: `findSpawnableAircraftGroupname` has two callers, and `spawnAFAC` reads the name only — see
ticket 02.

---

## Tickets, in full

## 01 — Route `getGroupData` through the mission index

Status: ✅ done

Type: fix · Files: `src/scripts/veaf/veaf.lua`, `src/scripts/veaf/veafMissionDb.lua`

### The change

`veaf.getGroupData` walked `env.mission` by hand and entered `red` and `blue` only, so every group
on the `neutrals` side was invisible to it. It also called `veaf.getGroupRecord` on its first line to
resolve the identifier and then threw the record away — the index had already been consulted and
already held the answer.

The function now asks the index and nothing else. For that, the group record carries the editor
table by reference (`missionData`), the same way it already carries `route` and a unit's `payload`:
callers read fields no projection carries, and no two of them read the same set — `communication`
and `frequency` for a tanker, a unit's `callsign`, `unitId` and `modulation` for a carrier's ATC,
`route.points[1].task` for a CAP. Projecting that set would be a second copy of the mission to keep
in step.

Second defect, one floor down and on the same side: the mission file spells the third coalition
`neutrals` and the scripting API spells it `NEUTRAL`, so `coalition.side[string.upper(coalitionName)]`
answered nil and **every neutral record went into the index with no `coalitionId` at all**. Making
the index the single answer means a hole in it is the same defect wearing a different hat, so it is
fixed here: `veafMissionDb.COALITION_SIDE_BY_MISSION_KEY` maps the mission-file key to the API name.

### The enumeration the PRD asked for

Every read of `env.mission.coalition` in `src/scripts/veaf/`, found with a literal search on the
expression and cross-checked against `coalitionData.country`, `coa_name`, `coa_data` and a search for
any alias of `env.mission`. **Three sites, no others:**

| Site | What it does | Verdict |
|---|---|---|
| `veaf.lua:2435` | hand-rolled walk, `red or blue` filter | **routed to the index** |
| `veafMissionDb.lua:159` (`buildSnapshot`) | the index's own walk, no coalition filter | correct — and it is now the only walk |
| `veafMissionDb.lua:268` (`getBullseye`) | keyed read `coalition[coalitionName]`, no walk | correct — no filter to get wrong; docstring corrected, it said `"blue" or "red"` and the third key is `neutrals` |

Adjacent, and **not** an `env.mission` walk, so outside what the PRD scoped: `refreshDynamicSlots`
(`veafMissionDb.lua:322`) sweeps `{ RED, BLUE }` of the **runtime** API. It is the only coalition
sweep in `src/scripts/veaf/` that omits `NEUTRAL` — the other three (`getGroupsOfCoalition`,
`getStaticsOfCoalition`, `veaf.lua:5800`) all include it. Editor-declared neutral slots are already
covered, `indexEditorSlots` reading the whole snapshot; the residual gap is a *dynamic* neutral slot,
and whether DCS creates such a thing cannot be settled without the game. Left for David to call.

### Definition of done

- [x] `veaf.getGroupData` finds a group whatever coalition holds it, neutral included
- [x] It goes through `veafMissionDb` rather than re-walking `env.mission` — one index, one answer
- [x] Name and editor-id lookups both still work
- [x] Every other hand-rolled walk of `env.mission.coalition` enumerated, and each routed or shown correct
- [x] A neutral record carries `coalition.side.NEUTRAL`, not nil
- [x] A test drives a **neutral** group through `getGroupData`, paired with the blue group that
      already worked, and both halves proven to fail on their own sabotage
- [x] `poetry run test-lua` green, `stylua --check src/scripts/veaf/ test/lua/` clean

---

## 02 — The CAP refusal must name the template it rejected

Status: ✅ done

Type: fix · File: `src/scripts/veaf/veafSpawnAircraft.lua`

### The change

`spawnCombatAirPatrol` fails for two different reasons and described both as the first one:

```lua
if not chosenTemplateName or not chosenTemplateData then
  ... "could not find a template for %s" ... veaf.p(name)
```

`name` is what the pilot typed. In the case that actually happened the name **was** matched —
fourteen templates answered to `mig29` and one was chosen — and it was the mission data behind it
that came back nil. So the log said *that aircraft does not exist* about an aircraft that did, and
sent every investigation to the template table and the search pattern. That is why ticket 01's defect
lived from 2026-03-14 to 2026-09-01.

The two cases are now separate, and the one that can name a template names it:

- nothing matched → `no aircraft template matches "mig29"`
- matched then dropped → `template "veafSpawn-MIG29-NEUTRAL" matched "mig29" but has no mission
  data, and was rejected`

### Also checked, per the PRD

Whether anything else asks for `chosenTemplateData` and silently drops a template it had found.
`veafSpawn.findSpawnableAircraftGroupname` has two callers: this one, and `spawnAFAC`
(`veafSpawnAircraft.lua:468`) which takes the name only and never reads the data, so it neither
dropped a template nor mis-reported one. Nothing else in `src/` calls it.

Found in passing and left alone: `VeafAirUnitTemplate:getGroupData()` has no caller anywhere in
`src/` — the setter is used by the `SpawnablePlanes` branch, the getter by nobody.

### Definition of done

- [x] The two failures are distinguished, and the message says which one happened
- [x] The rejected template is named when there is one to name
- [x] The no-match message still names the pilot's input, and names no template
- [x] A test asserts the message contains the template name, and fails when it prints the input instead
- [x] A readable template is not refused — so the assertions above are not passing on an always-failing spawn
- [x] `poetry run test-lua` green, `stylua --check src/scripts/veaf/ test/lua/` clean

---
