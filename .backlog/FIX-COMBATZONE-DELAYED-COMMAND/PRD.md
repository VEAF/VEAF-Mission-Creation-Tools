# FIX-COMBATZONE-DELAYED-COMMAND — a delayed command's group outlives its zone

Status: ⬜ ready

Origin: `CHORE-ISSUE-VERIFY-SESSION` check 8, confirmed in DCS by David on 2026-08-18. Closes
[#66](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/66), open since the v5 era.

## The defect, and it is visible in the code

A combat zone can carry a VEAF command on a fake unit — `#command="-samsr!30"`, the `!30` being a
delay. The zone runs it through `veafInterpreter.execute`, passing a `spawnedGroups` table it then
iterates to register what was created (`veafCombatZone.lua:1117`).

With a delay, `veafShortcuts.ExecuteAlias` hands the work to `mist.scheduleFunction` and **returns
immediately** (`veafShortcuts.lua:540`). The table is still empty when the zone reads it. The group
appears 30 seconds later, registered nowhere — so `VeafCombatZone:desactivate()`, which destroys
`getSpawnedGroups()`, cannot destroy it. The SAM survives the zone that spawned it.

The zone's own `#spawndelay=30` does not have the problem: it delays `spawnElement`, which registers
the group on the way through. Two delay mechanisms, one broken — the verification mission carries
**both**, side by side, so the difference is observable rather than argued.

## What ships

The delayed path must return its groups to whoever asked for them. Two shapes, and the choice
matters:

- a **callback** given to `ExecuteAlias`, invoked when the deferred spawn completes — the zone
  registers late, and anything else wanting delayed spawns gets the same guarantee
- or the zone **owning the delay itself**, translating `!30` into its own `spawnDelay` and never
  handing a delay to the interpreter

The second is smaller but only fixes combat zones; the delayed-alias path stays lossy for every other
caller. Prefer the first unless there is a reason not to, and write down which was chosen.

## Definition of done

- [ ] A group spawned by a delayed `#command` is registered with its zone and destroyed on deactivation
- [ ] `#spawndelay` keeps working exactly as it does now
- [ ] Lua test covering both delay mechanisms, since the fix must not make the working one worse
- [ ] Re-run check 8 of `verify-mission-c`: the zone `DelayZone` already carries one fake unit per
      mechanism
- [ ] #66 closed citing the reproduction and this cause
