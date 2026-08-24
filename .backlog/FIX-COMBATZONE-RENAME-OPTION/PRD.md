# FIX-COMBATZONE-RENAME-OPTION — let a mission maker keep the original unit names while debugging

Status: 🧑 waiting-human

Shipped in 6.15.16, with `FIX-COMBATZONE-ZONE-TYPE-SILENT`. Waiting only on **telling Sharko on #289**,
which is David's to do — the code, the tests and the documentation are done and need no DCS.

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

## What shipped

A per-zone setting, following the shape `FIX-CONVERT-V5-SILENT-LOSSES` established for the other six —
so this is the seventh member of a family rather than a new pattern:

| Layer | Change |
|---|---|
| runtime | `renameUnitsSequentially = true` on the prototype, `setRenameUnitsSequentially` / `isRenameUnitsSequentially`, and `spawnElement` reads it instead of the hard-coded `true` |
| `lua_config_generator` | emits `:setRenameUnitsSequentially(false)` **only** for a `false`, so existing generated Lua is byte-identical |
| `config_migrator` | reads `:setRenameUnitsSequentially(false)` out of a v5 mission, ignoring `true` |
| `mission.yaml` key | `rename_units_sequentially`, default `true` |
| documentation | both pages, plus **the four keys of the `SILENT-LOSSES` family that were never documented** — `show_units_list`, `show_zone_position_info`, `smoke_and_flare` and `radio_menu_disabled` were accepted by the generator and absent from the reference table |
| `src/defaults/mission-folder/mission.yaml` | the commented example, per the defaults lockstep |

The Lua tests assert the **vars handed to MiST**, not the setter. A setter storing a value nobody reads
is exactly the defect `FIX-COMBATZONE-DEAD-SPAWN-RADIUS-DEFAULT` had just spent a lot fixing.

## Definition of done

- [x] A combat zone can keep its units' original names, declared in `mission.yaml`
- [x] Default unchanged: existing missions keep sequential renaming and their generated Lua is
      byte-identical
- [x] Extraction and emission both covered, with the "remove the setter, the key disappears" shape of
      test the reporter's own harness uses
- [x] Documented in the combat-zone reference, **both languages**
- [ ] Sharko told on #289, since he has been waiting since February 2025 — **David's to do**
