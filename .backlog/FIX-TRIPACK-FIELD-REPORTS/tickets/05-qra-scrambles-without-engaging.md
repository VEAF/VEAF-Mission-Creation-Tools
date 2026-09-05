# 05 — A cloned group loses the mission task the editor gave it

Status: ⬜ ready

Type: fix

Measured 2026-09-05 on Tripack's `Snowfox_20260903.miz` and `src(4).zip`. The ticket opened with no
diagnosis; the mission gave one.

## The report

*"réaction bizarre des avions de la QRA, tout se déclenche mais ils font leur nav tranquilos … la
semaine passée ils étaient méchants, rien touché de mon côté depuis"* — Tripack, 2026-09-03, between
6.16.0 and 6.19.0.

## What his mission actually declares

`QRA_SOUTH` deploys pre-placed DCS groups, so it takes the DCS-group branch of `VeafQRACore:deploy`
and ends on `VeafGroupSpawn:…:clone()` ([`veafQraCore.lua:1042`](../../../src/scripts/veaf/veafQraCore.lua)):

```lua
:setRandomGroupsToDeployByEnemyQuantity(1, {"CAP_AL_MINHAD-1", …, "CAP_FUJAIRAH-6"}, 1)
```

`CAP_AL_MINHAD-1`, read out of the mission table:

| Field | Value |
|---|---|
| `task` | **`'CAP'`** |
| `taskSelected` | `true` |
| `uncontrolled` | `false` |
| `frequency` / `modulation` | `251.5` / `0` |
| `hidden` | `true` |
| route wp2 | `ComboTask` holding **`EngageTargetsInZone`** |

So the editor gives these fighters both halves of what makes them fight: a group-level mission task,
and a per-waypoint engagement task.

## What the clone submits

`_sourceData("clone")` reads `veafMissionDb.getGroupRecord`, and that record carries exactly ten
fields: `groupName`, `groupId`, `coalition`, `coalitionId`, `category`, `country`, `countryId`,
`units`, `route`, `missionData`. **The word `task` does not appear anywhere in
[`veafMissionDb.lua`](../../../src/scripts/veaf/veafMissionDb.lua)** — verified, zero matches.

`addGroup` then fills in `hidden`, `visible` and `start_time` and submits. Nothing puts `task` back,
and `veafQraCore` sets no task of its own after the spawn — no `setTask`, no `goRoute`, no
`readyForCombat`.

So `coalition.addGroup` receives a CAP flight with **no mission task**. The per-waypoint
`EngageTargetsInZone` survives, because the route projection does carry `task` per point; the group's
own `'CAP'` does not.

## Why this is a regression and not a long-standing gap

MiST carried it. `mist.DBs` is built with
`mist.DBs.units[coa][country][category][n].task = group_data.task`
([`mist.lua:264`](../../../src/scripts/community/mist.lua)), and `getCurrentGroupData` restores
`task`, `modulation`, `uncontrolled`, `radioSet`, `hidden` and `startTime` from what it recorded
([`mist.lua:1030`](../../../src/scripts/community/mist.lua)). Every VEAF clone went through that
table until `REFACTOR-SPAWNER` replaced it — which lands the change squarely between the version
where Tripack's QRA was *"méchante"* and the one where it is not.

**Not proven**: that DCS specifically makes an aircraft passive when `task` is absent. What is proven
is the loss of a field the editor set and MiST forwarded. Settling the behaviour needs the game and
belongs in `DCS-SESSION-TODO.md`; the fix does not wait on it, because forwarding what the mission
maker wrote is correct either way.

## The blast radius is wider than the QRA

Every field the editor sets at group level and the record does not carry is lost by **every** clone
and respawn — air waves, combat missions, combat zones, assets, `veafMove` escorts:

`task`, `taskSelected`, `uncontrolled`, `frequency`, `modulation`, `communication`, `radioSet`.

Two are worth calling out. `frequency`/`communication` explains a comment already in the tree —
`veafMove.lua:952`, *"have to set the frequency again as setTask seems to ignore missionData.frequency
and switch the unit to 124AM"*, which reads like a symptom of this same loss. And `hidden`: the editor
hides these QRA groups, `addGroup` defaults a missing `hidden` to `false`, so every scrambled flight
becomes visible on the F10 map — cheap to check against Tripack's own screenshot.

## The fix

Carry the group-level fields in the record. `missionData` is already held by reference, so the data
is there and the cost is naming the fields; do not project the whole editor table, which the record's
own docstring rejects on purpose. Enumerate the fields from the mission schema rather than from the
seven found here — the sweep is the deliverable, not a sample.

## Definition of done

- [ ] A cloned or respawned group reaches DCS carrying the group-level fields the editor set,
      `task` included
- [ ] The field list is enumerated from the schema, not sampled, and a test walks it
- [ ] Test asserts **the wiring**: what `coalition.addGroup` is handed for a QRA scramble, not that a
      helper was called
- [ ] `hidden` is forwarded rather than defaulted when the editor set it
- [ ] In-game check queued in `DCS-SESSION-TODO.md`: a scrambled QRA engages
- [ ] `luacheck` + `stylua --check` clean; Lua coverage floor bumped per the ratchet policy
