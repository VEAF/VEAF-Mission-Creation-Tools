# FIX-CLONE-KEEPS-UNIT-NAMES — a clone that names its own group despawns the previous one

Status: ⬜ ready

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

## Regression from DROP-MIST

`mist.dynAdd` renamed a clone's units unconditionally. The port rebuilt this by hand and the comment
records that the **group** rename was missed and then restored; the **unit** rename was missed in the
same pass and not restored. `veafSpawnAircraft:1114` went from `mist.teleportToPoint(vars, true)` with
`vars.action = "clone"` to `VeafGroupSpawn:…:buildCloneData()` on 2026-08-30 (#840).

## Definition of done

- [ ] A clone always renames its units, whatever the caller did about the group name
- [ ] `renameUnits` keeps its meaning for the callers that ask for the `#` form explicitly — the two
      naming shapes (`<group> #<n>` and `<group>-<n>`) exist for different readers and neither is
      dropped
- [ ] A test spawns the **same template twice** and asserts both groups are alive with distinct unit
      names — the case that fails today
- [ ] The three broken callers covered, not just the CAP: an enumeration, not a sample
- [ ] A test proves the fallback path still works, so the fix does not quietly replace one branch
      with another
- [ ] `CHANGELOG.md` says what a mission maker sees: spawning the same CAP, AFAC or combat-mission
      group twice used to remove the first one

## Worth checking in the same pass

Whether anything downstream tracks these groups **by unit name** and would now see names it does not
expect — the CAP watchdog and the AFAC callsign registry both track their groups by name.
