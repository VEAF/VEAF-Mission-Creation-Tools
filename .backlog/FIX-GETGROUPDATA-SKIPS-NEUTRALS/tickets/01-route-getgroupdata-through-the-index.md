# 01 — Route `getGroupData` through the mission index

Status: ✅ done

Type: fix · Files: `src/scripts/veaf/veaf.lua`, `src/scripts/veaf/veafMissionDb.lua`

## The change

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

## The enumeration the PRD asked for

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

## Definition of done

- [x] `veaf.getGroupData` finds a group whatever coalition holds it, neutral included
- [x] It goes through `veafMissionDb` rather than re-walking `env.mission` — one index, one answer
- [x] Name and editor-id lookups both still work
- [x] Every other hand-rolled walk of `env.mission.coalition` enumerated, and each routed or shown correct
- [x] A neutral record carries `coalition.side.NEUTRAL`, not nil
- [x] A test drives a **neutral** group through `getGroupData`, paired with the blue group that
      already worked, and both halves proven to fail on their own sabotage
- [x] `poetry run test-lua` green, `stylua --check src/scripts/veaf/ test/lua/` clean
