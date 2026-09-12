# 01 — Resolve a static by its unit name

Status: ✅ done

## What

Three sites ask `veafMissionDb.getGroupRecord(name)` with a name that came off a **live object**. For
a static that name is the unit's, and the record is keyed by group — so the lookup answers nil and
the caller gives up.

Add one resolution used by all three: the group record whose name matches, or failing that, the
record of the group the **unit** of that name belongs to (`unitRecord` already carries `groupName`).

`getGroupRecord` itself is left alone. It answers "is there a group called this", which
`veafMove.lua:723` asks as a question rather than as a way to reach data; widening it would make that
test say yes for a unit name.

## Where

- `veafMissionDb.getGroupRecordForObject(name)` — new, next to `getGroupRecord`
- `veafDcsSpawner.lua:905` (`VeafGroupSpawn:_sourceData`, the clone and respawn verbs)
- `veafDcsSpawner.lua:630` (`getCurrentGroupData`, the teleport verb)
- `veafCombatZone.lua:1632` (`surfacesForZoneElement`)

## Tests

In `test_veafMissionDb.lua`:

- a static whose unit is named `<group>-1` resolves to its group record
- a static whose unit is named exactly like its group resolves to the same record (the half that
  already worked, so the fix does not trade one shape for the other)
- a name that is neither resolves to nil
- `getGroupRecord` still answers nil for a unit name

In `test_veafDcsSpawner.lua`:

- respawning by the unit name of a static creates the object, instead of logging `no group data`
- the created static keeps the editor's `hidden`

## Done when

- The twelve `cannot respawn […-1]: no group data` lines cannot happen again for a mission-editor
  static
- No existing test changes meaning to make it pass
