# FIX-COMBATZONE-RENAME-OPTION — let a mission maker keep the original unit names while debugging

Status: ⬜ ready

Origin: [#289](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/289), Sharko, 2025-02-03.
Reclassified from `verify` to `still-valid` on 2026-08-17 once the cause was found: it is one
hard-coded line, not an unknown.

## The request, in his words

Renaming a combat zone's units is very useful **once the map is finished**. While testing or
debugging a `.miz`, no longer seeing the original unit name makes the work harder — he asks for a
switch.

## Why it cannot be turned off today

`veafCombatZone.lua:1098`:

```lua
vars.renameUnitsSequentially = true
```

Hard-coded in the `mist.teleportToPoint` call that respawns a zone element. No config read, no zone
property, no global. Grepped: `renameUnitsSequentially` occurs **once** in the whole runtime, at that
line. So there is nothing to set, and the answer to "can I turn it off?" is no.

## Scope

One ticket. Make it a **zone-level setting** rather than a global, following whatever `completable`
established as the YAML convention (`FIX-CONVERT-V5-SILENT-LOSSES` ticket 03 just added five keys
that way, so the pattern is fresh):

- a `combat_zones:` key, default **true** — today's behaviour, so no existing mission changes
- the setter on `VeafCombatZone`, emitted by `lua_config_generator` only when `false`
- `_parse_combat_zone` reads it, so a v5 mission using it converts

A zone-level switch rather than a debug global, because that is what he asked for and because a
global would be one more thing to remember to turn back off before shipping.

## Definition of done

- [ ] A combat zone can keep its units' original names, declared in `mission.yaml`
- [ ] Default unchanged: existing missions keep sequential renaming and their generated Lua is
      byte-identical
- [ ] Extraction and emission both covered, with the "remove the setter, the key disappears" shape of
      test the reporter's own harness uses
- [ ] Documented in the combat-zone reference, **both languages**
- [ ] Sharko told on #289, since he has been waiting since February 2025
