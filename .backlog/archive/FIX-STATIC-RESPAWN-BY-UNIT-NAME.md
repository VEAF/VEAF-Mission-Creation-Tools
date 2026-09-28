# FIX-STATIC-RESPAWN-BY-UNIT-NAME — a static whose unit is not named like its group is never put back

Status: ✅ done — merged in #954, 2026-09-12 · archived 2026-09-28

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
| 01 | [Resolve a static by its unit name](FIX-STATIC-RESPAWN-BY-UNIT-NAME.md) | ✅ |
| 02 | [Carry hiddenOnMFD and hiddenOnPlanner](FIX-STATIC-RESPAWN-BY-UNIT-NAME.md) | ✅ |

## Definition of done

- [x] A zone static whose unit name differs from its group name is respawned, and the log line is gone
- [x] The same resolution serves the teleport and the naval terrain check, which fail on the same name
- [x] `hiddenOnMFD` and `hiddenOnPlanner` survive a clone and a respawn
- [x] Tests cover both name shapes (unit == group, and unit == group .. "-1"), because the mission
      that found this had both and only one half was broken
- [x] Tripack answered on #953: his five lost sandbags, and his `optview_all` forced option

---

## Tickets, in full

## 01 — Resolve a static by its unit name

Status: ✅ done

### What

Three sites ask `veafMissionDb.getGroupRecord(name)` with a name that came off a **live object**. For
a static that name is the unit's, and the record is keyed by group — so the lookup answers nil and
the caller gives up.

Add one resolution used by all three: the group record whose name matches, or failing that, the
record of the group the **unit** of that name belongs to (`unitRecord` already carries `groupName`).

`getGroupRecord` itself is left alone. It answers "is there a group called this", which
`veafMove.lua:723` asks as a question rather than as a way to reach data; widening it would make that
test say yes for a unit name.

### Where

- `veafMissionDb.getGroupRecordForObject(name)` — new, next to `getGroupRecord`
- `veafDcsSpawner.lua:905` (`VeafGroupSpawn:_sourceData`, the clone and respawn verbs)
- `veafDcsSpawner.lua:630` (`getCurrentGroupData`, the teleport verb)
- `veafCombatZone.lua:1632` (`surfacesForZoneElement`)

### Tests

In `test_veafMissionDb.lua`:

- a static whose unit is named `<group>-1` resolves to its group record
- a static whose unit is named exactly like its group resolves to the same record (the half that
  already worked, so the fix does not trade one shape for the other)
- a name that is neither resolves to nil
- `getGroupRecord` still answers nil for a unit name

In `test_veafDcsSpawner.lua`:

- respawning by the unit name of a static creates the object, instead of logging `no group data`
- the created static keeps the editor's `hidden`

### Done when

- The twelve `cannot respawn […-1]: no group data` lines cannot happen again for a mission-editor
  static
- No existing test changes meaning to make it pass

---

## 02 — Carry hiddenOnMFD and hiddenOnPlanner

Status: ✅ done

### What

The group record carries `hidden` and not its two neighbours. The Mission Editor writes all three
together — Tripack's mission has `hidden`, `hiddenOnMFD` and `hiddenOnPlanner` all true on 446 of its
469 groups — so anything VEAF puts back on the map comes back visible on every datalink display and
in the mission planner, whatever DCS does with `hidden` itself.

Two fields in `veafMissionDb`'s group record, forwarded by the same path `hidden` already takes
(`addGroup` submits the record as it stands; `addStatic` hoists unit fields over it and leaves
group-level ones alone).

No default is invented for them: `nil` when the editor said nothing, exactly as the record does for
`task`, `frequency` and the rest. `addGroup` defaults `hidden` to `false` and that stays its own
business.

### Not in scope, deliberately

`getCurrentGroupData` clears `uncontrolled` and `hidden` for a **teleport**, restored on David's call
on 2026-09-07. These two fields are not added to that clearing: the decision it implements was about
an aircraft arriving unusable and about the F10 map, and nothing measured says a teleported group
should also reappear on a datalink. Changing it would be a behaviour change this lot did not measure.

### Tests

In `test_veafMissionDb.lua`: a group with the three flags set records the three; a group with none
records nil for the three.

In `test_veafDcsSpawner.lua`: a clone and a respawn both submit `hiddenOnMFD` / `hiddenOnPlanner` as
the editor set them.

### Done when

- A respawned group is as hidden as the editor made it, on all three surfaces
- The coverage floor moves with the new tests, per the quality ratchet

---
