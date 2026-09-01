# 02 — The three callers that thought they were renaming, and were not

Status: ✅ done

Type: fix · Files: `src/scripts/veaf/veafSpawnAircraft.lua`, `src/scripts/veaf/veafCombatMission.lua`,
`test/lua/test_veafSpawn.lua`, `test/lua/test_veafCombatMission.lua`

## The enumeration, re-done

Every caller of `clone()` / `buildCloneData()` in the repository, and what each did about its unit
names **before** ticket 01:

| Caller | Group name | Its own unit renaming | Collided? |
|---|---|---|---|
| `veafSpawnAircraft:1114` (CAP) | `:named("<template> #%04d")` | wrote `unit.name`, which `addGroup` overwrites from `unit.unitName` | yes, every time |
| `veafSpawnAircraft:638` (AFAC) | `:named(<callsign>)` | forces the callsign onto **unit 1 only** | yes, from unit 2 on |
| `veafCombatMission:897` | relabelled `groupName` *after* building | wrote `unit.groupName`, a field nothing reads | yes, from the 2nd clone on |
| `veafAirWaves:1073` | none | none | no |
| `veafQraCore:1043` | none | none | no |

The two that ask for nothing are the two that worked: with no name supplied, the template's own name
is taken, so the group was renamed and the units followed. The three that did the careful thing broke.

Two corrections to the lot's opening description, both measured:

- the **AFAC** is not broken on a single-aircraft template: it overwrites its first unit's name with
  the callsign, and a callsign is unique. It breaks on any template with a wingman;
- **`veafCombatMission` does not supply its name through `named()`** — it overwrites `groupName`
  after `buildCloneData()`. So `isNameTaken` saw the *template* name, answered yes, and the units
  were renamed after the intermediate name `freeNameFrom` picked. Nothing ever registers that
  intermediate name, so every clone of the template picked the same one. Ticket 01 alone does not fix
  this caller; the test proves it.

## What was done

- **CAP**: the dead renaming loop is gone. It read `unit.unitName or unit.name`, built
  `<unit> #0001`, and assigned it to `unit.name` — which `addGroup` then overwrote from
  `unit.unitName`. Measured: the submitted names are identical with and without the loop. It also
  grew `veafSpawn.spawnedNamesIndex` by one key per clone forever.
- **`veafCombatMission`**: the clone is named through `named(spawnedGroupName)` instead of being
  relabelled afterwards, so its units are named after the name DCS actually receives. Its own
  renaming loop is gone with it — it wrote into `unit.groupName`.
- **AFAC**: unchanged. It keeps forcing the callsign onto unit 1, which is its identity everywhere
  downstream; ticket 01 now names the wingmen.

## Downstream tracking by unit name

Checked, since renaming units could break whatever follows them:

- the **CAP watchdog** takes the *group* name, resolves it with `Group.getByName`, and iterates
  `getUnits()` — DCS objects, never a unit name as a key;
- the **AFAC callsign registry** is keyed by callsign index; the watchdog looks the group up by
  callsign, and `veafMove.moveAfac` matches the *group* name against the callsign list;
- `addGroup`'s payload fallback (`getUnitRecord(unit.unitName …)`) is never reached for a clone: the
  mission record carries each unit's payload, so `unit.payload` is already set.

Nothing downstream tracks these groups by unit name.

## Definition of done

- [x] The enumeration re-done from the code, not from a pattern search
- [x] CAP, AFAC and combat mission each covered by a test that spawns the same template twice
- [x] The two callers that already worked still work
- [x] Downstream tracking checked and reported
