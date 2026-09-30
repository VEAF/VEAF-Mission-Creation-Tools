# FIX-CLONE-KEEPS-UNIT-NAMES — a clone that names its own group despawns the previous one

Status: ✅ done — 2026-09-01 · archived 2026-09-28

Found in game 2026-09-01 by David: *"on ne peut pas lancer 2 fois `-cap f15` — la seconde fois
téléporte le groupe existant. C'est le bug classique du clone qui est en fait un teleport."*

Right diagnosis, one level down: it is the **units** that keep their names, not the group.

## The defect

`VeafGroupSpawn:_spawn` (`veafDcsSpawner.lua:971`) renames a clone's units in two cases only:

```lua
if self.renameUnits then
  ...
elseif renamed then          -- `renamed` is true ONLY if the GROUP name was already taken
```

A caller that supplies its own unique group name — `veafSpawn-f15-fox1 #0001`, `#0002`, … — makes
`isNameTaken` answer **no**, so `renamed` stays false and the units keep the template's names. The
second `-cap f15` on the same template submits units DCS already knows, and DCS removes the first
ones. Which is exactly a teleport, as David said.

The code already carries the argument, two lines below:

> *A renamed group renames its units too: DCS is no happier about two `Convoy-1` than about two
> `Convoy`.*

The rule is right and wired to the wrong switch. **A clone creates a new identity by definition, so
it must always rename its units.** "The group name was taken" is one case of that, not the condition.

## The five callers, enumerated

None of them asks for `renameUnits`. They split into two groups, and the split is the tell:

| Caller | Supplies a name? | What happens |
|---|---|---|
| `veafSpawnAircraft:1114` (CAP) | yes, `#%04d` counter | never renamed → **collision every time** |
| `veafSpawnAircraft:638` (AFAC) | yes, a callsign | never renamed → **collision every time** |
| `veafCombatMission:897` | yes, `#%04d` counter | never renamed → **collision every time** |
| `veafAirWaves:1073` | **no** | name taken from the 2nd wave on → renamed → works |
| `veafQraCore:1043` | **no** | same → works |

So the two that look sloppiest are the two that work, by falling into the fallback path. The three
that do the careful thing — allocate a unique name — are the three that break.

### Two corrections to that table, measured while fixing it

The shape of the split holds; two rows are wrong about *why*, and one of them means ticket 01 alone
does not fix its caller.

- **AFAC** (`veafSpawnAircraft:638`) — not broken on a single-aircraft template. It overwrites its
  first unit's name with the callsign right after building the clone, and a callsign is unique by
  construction. It breaks on any template with a **wingman**: units 2..n keep the template's names.
  A CAP-style two-ship is what an AFAC template usually is, so the defect is real — but the first
  unit, the one every downstream lookup uses, was never the problem.
- **`veafCombatMission:897`** — does **not** supply its name through `named()`. It calls
  `buildCloneData()` with no name and overwrites `groupName` afterwards. So `isNameTaken` saw the
  *template* name, answered yes, and the units were renamed — after the intermediate name
  `freeNameFrom` picked. Nothing ever registers that intermediate name (`addGroup` registers what DCS
  was given, which is the caller's later name), so **every** clone of the template picked the very
  same intermediate name, and every clone submitted the same unit names. This caller reaches the same
  outcome by the opposite road, and only ticket 02 repairs it.

And a third finding on the CAP, which is the one David actually ran: it *does* rename its units, into
`unit.name`, which `addGroup` then overwrites from `unit.unitName` — the template's name, untouched.
The rename has never had any effect. That loop is gone; the measured submitted names are identical
with and without it.

## Regression from DROP-MIST

`mist.dynAdd` renamed a clone's units unconditionally. The port rebuilt this by hand and the comment
records that the **group** rename was missed and then restored; the **unit** rename was missed in the
same pass and not restored. `veafSpawnAircraft:1114` went from `mist.teleportToPoint(vars, true)` with
`vars.action = "clone"` to `VeafGroupSpawn:…:buildCloneData()` on 2026-08-30 (#840).

## Scope

| # | Ticket | Type | Status |
|---|--------|------|--------|
| 01 | [A clone always renames its units](FIX-CLONE-KEEPS-UNIT-NAMES.md) | fix | ✅ |
| 02 | [The three callers that renamed nothing](FIX-CLONE-KEEPS-UNIT-NAMES.md) | fix | ✅ |

## Definition of done

- [x] A clone always renames its units, whatever the caller did about the group name
- [x] `renameUnits` keeps its meaning for the callers that ask for the `#` form explicitly — the two
      naming shapes (`<group> #<n>` and `<group>-<n>`) exist for different readers and neither is
      dropped
- [x] A test spawns the **same template twice** and asserts both groups are alive with distinct unit
      names — the case that fails today
- [x] The three broken callers covered, not just the CAP: an enumeration, not a sample
- [x] A test proves the fallback path still works, so the fix does not quietly replace one branch
      with another
- [x] `CHANGELOG.md` says what a mission maker sees: spawning the same CAP, AFAC or combat-mission
      group twice used to remove the first one

## Worth checking in the same pass

Whether anything downstream tracks these groups **by unit name** and would now see names it does not
expect — the CAP watchdog and the AFAC callsign registry both track their groups by name.

**Answer: nothing does.** Checked, one site at a time:

- the **CAP watchdog** is given the *group* name, resolves it with `Group.getByName`, and then
  iterates `capGroup:getUnits()` — DCS unit objects. `unit:getName()` is only ever logged;
- the **AFAC callsign registry** is keyed by callsign index. `afacWatchdog` looks the group up by
  callsign, `releaseSpawnedName` releases the *group* name, and `veafMove.moveAfac` matches
  `groupName:find(callsign)` — group names throughout. The AFAC's own unit 1 still carries the
  callsign, unchanged;
- `veafCombatMission` tracks the DCS group object, `veafAirWaves` and `veafQraCore` track group names;
- one near miss worth naming: `addGroup` fills a missing aircraft loadout with
  `getUnitRecord(unit.unitName or unit.name)`, which a renamed unit would no longer find. It is never
  reached for a clone — the mission record carries each unit's `payload`, so `unit.payload` is
  already set by the time `addGroup` looks. The two callers that already renamed their units
  (`veafAirWaves`, `veafQraCore`) have been exercising that path all along.

## Not done here

`veafSpawn.spawnedNamesIndex[groupName]` is still initialised and incremented on the **AFAC** path
(`veafSpawnAircraft:514` and `:748`) and never read by anything: the AFAC's name comes from the
callsign table. Pre-existing, unrelated to unit names, and left alone rather than folded into a fix.

---

## Tickets, in full

## 01 — A clone always renames its units

Status: ✅ done

Type: fix · Files: `src/scripts/veaf/veafDcsSpawner.lua`, `test/lua/test_veafDcsSpawner.lua`

### What was wrong

`VeafGroupSpawn:_spawn` renamed a clone's units in two cases only:

```lua
if self.renameUnits then
  ...
elseif renamed then          -- true ONLY if the GROUP name was already taken
```

`renamed` is the answer to "did I have to invent a group name?", not to "is this a new identity?".
A caller that allocates its own unique group name makes `isNameTaken` answer no, so its units kept
the template's names.

### What was done

The condition is `verb == "clone"`. A clone creates a new identity by definition, so it renames its
units whatever the caller did about the group name.

Both naming shapes are kept, and they mean different things:

| Shape | Asked for by | Reader |
|---|---|---|
| `<group> #<n>` | `renamingUnitsSequentially()` (`veafCombatZone`) | a mission maker reading a zone's units |
| `<group>-<n>` | every clone, by default | the Mission Editor's own shape; `Arco #2 #1` reads as nothing |

The unit names are unique because the group name is. That is now stated in the code, because it is
what ticket 02 had to repair on the caller side.

### Definition of done

- [x] A clone renames its units whether or not its group had to be renamed
- [x] `renameUnits` keeps its own meaning and its own shape
- [x] A respawn and a teleport still keep their unit names
- [x] Tests red before the change, green after

---

## 02 — The three callers that thought they were renaming, and were not

Status: ✅ done

Type: fix · Files: `src/scripts/veaf/veafSpawnAircraft.lua`, `src/scripts/veaf/veafCombatMission.lua`,
`test/lua/test_veafSpawn.lua`, `test/lua/test_veafCombatMission.lua`

### The enumeration, re-done

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

### What was done

- **CAP**: the dead renaming loop is gone. It read `unit.unitName or unit.name`, built
  `<unit> #0001`, and assigned it to `unit.name` — which `addGroup` then overwrote from
  `unit.unitName`. Measured: the submitted names are identical with and without the loop. It also
  grew `veafSpawn.spawnedNamesIndex` by one key per clone forever.
- **`veafCombatMission`**: the clone is named through `named(spawnedGroupName)` instead of being
  relabelled afterwards, so its units are named after the name DCS actually receives. Its own
  renaming loop is gone with it — it wrote into `unit.groupName`.
- **AFAC**: unchanged. It keeps forcing the callsign onto unit 1, which is its identity everywhere
  downstream; ticket 01 now names the wingmen.

### Downstream tracking by unit name

Checked, since renaming units could break whatever follows them:

- the **CAP watchdog** takes the *group* name, resolves it with `Group.getByName`, and iterates
  `getUnits()` — DCS objects, never a unit name as a key;
- the **AFAC callsign registry** is keyed by callsign index; the watchdog looks the group up by
  callsign, and `veafMove.moveAfac` matches the *group* name against the callsign list;
- `addGroup`'s payload fallback (`getUnitRecord(unit.unitName …)`) is never reached for a clone: the
  mission record carries each unit's payload, so `unit.payload` is already set.

Nothing downstream tracks these groups by unit name.

### Definition of done

- [x] The enumeration re-done from the code, not from a pattern search
- [x] CAP, AFAC and combat mission each covered by a test that spawns the same template twice
- [x] The two callers that already worked still work
- [x] Downstream tracking checked and reported

---
