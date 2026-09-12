# FIX-STATIC-RESPAWN-BY-UNIT-NAME — a static whose unit is not named like its group is never put back

Status: 🔄 in-progress

Found in [#953](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/953)'s attachments, which
Tripack filed about something else: his server log carries twelve

```
VEAF-SPAWNER: cannot respawn [CMBT_AL_DHAFRA_AIRPORT - Sac de sable 02-4-1]: no group data
```

## The defect, and why the name has a `-1` too many

A static object answers, at runtime, to the name of its **unit**. In the mission table it still lives
inside a group, and the two names are only the same when the mission maker never renamed anything:
duplicating a static in the Mission Editor produces a group `Sac de sable 02-4` holding a unit
`Sac de sable 02-4-1`.

`veafCombatZone.getGroupNameOfUnit` (`veafCombatZone.lua:250`) records the runtime name — *"which is
its own group"*, true of the live object and false of the mission table. Everything downstream then
looks that name up as a **group**:

| site | what it asks | what happens with a `-1` name |
|------|--------------|-------------------------------|
| `VeafGroupSpawn:_sourceData` (`veafDcsSpawner.lua:905`) | `getGroupRecord(name)` | `no group data` — the static is **never respawned** |
| `veafDcsSpawner.getCurrentGroupData` (`:630`) | `getGroupRecord(name)` | a teleported static finds no record and moves nothing |
| `surfacesForZoneElement` (`veafCombatZone.lua:1632`) | `getGroupRecord(name)` | a hull placed as a static loses its naval terrain and is searched a spot on dry land |

Destruction is not symmetrical with it: `StaticObject.getByName` answers to the unit name, so
deactivating a zone **does** destroy the object. Destroyed on deactivation, not recreated on
activation — the static is gone from the mission for good, and nothing says so above `info`.

Measured on Tripack's mission: of eight neutral sandbag statics, three carry a unit named exactly
like its group and come back; **five carry the `-1` suffix and are lost**.

## Found by the review of this lot, and fixed here

Reaching the record through a unit name has a trap on the **teleport** path: the record names the
*group*, and `_spawn` falls back on `data.groupName` for the identity it submits. A static called
`Bunker 02-4-1` would therefore have been moved *and* renamed `Bunker 02-4` — worse than the refusal
the lookup replaced, since `veafMove` and the combat zone both track their objects by name. The
static branch of `getCurrentGroupData` now pins the name it was asked for, as the group branch
already did. Locked by `test_a_teleported_static_keeps_the_name_it_answers_to`.

## What this lot does *not* settle

#953 reports the opposite symptom — objects hidden in the editor showing up on the F10 map of a
**remote** server. Two facts measured while reading his mission say that is a different question:

- the `.miz` is correct (all twelve QRA groups and all eight sandbags carry `hidden = true`), and the
  respawn chain carries `hidden` end to end — `veafMissionDb` records it (`:232`), `addGroup` honours
  it, and `test_a_clone_keeps_the_editors_hidden_flag` already locks it;
- his mission forces the map view for every client: `forcedOptions.optionsView = "optview_all"`,
  against `optview_onlyallies` in its own `options` file. Forced options apply to clients joining a
  server, which is exactly the "remote server only" shape of his report. veaf-tools does not write
  that field (`blank_mission.py` leaves `forcedOptions` empty).

Whether DCS honours `hidden` at all on an object created through `coalition.addGroup` /
`addStaticObject` can only be read off an F10 map in game. The check is written up as item R15
in [`DCS-SESSION-TODO.md`](../../DCS-SESSION-TODO.md), with both outcomes stated.

## Tickets

| # | Ticket | Status |
|---|--------|--------|
| 01 | [Resolve a static by its unit name](tickets/01-resolve-a-static-by-its-unit-name.md) | ✅ |
| 02 | [Carry hiddenOnMFD and hiddenOnPlanner](tickets/02-carry-hidden-on-mfd-and-planner.md) | ✅ |

## Definition of done

- [x] A zone static whose unit name differs from its group name is respawned, and the log line is gone
- [x] The same resolution serves the teleport and the naval terrain check, which fail on the same name
- [x] `hiddenOnMFD` and `hiddenOnPlanner` survive a clone and a respawn
- [x] Tests cover both name shapes (unit == group, and unit == group .. "-1"), because the mission
      that found this had both and only one half was broken
- [ ] Tripack answered on #953: his five lost sandbags, and his `optview_all` forced option
