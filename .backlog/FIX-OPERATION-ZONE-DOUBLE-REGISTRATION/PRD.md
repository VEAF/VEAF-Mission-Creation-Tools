# FIX-OPERATION-ZONE-DOUBLE-REGISTRATION — a combat zone an operation lists is registered once

Status: 🔄 in progress

Origin: validating `veaf-tools dcs mission-check` (FEAT-DCS-RECON-AND-MISSION-CHECK, #1207) in a running DCS on "Marteau du Golan" (Syria), 2026-10-28.

## Problem

The generated `veaf-config.lua` adds every combat zone with `veafCombatZone.AddZone(...)`, then builds each operation with `:addTaskingOrder(veafCombatZone.GetZone("<member>"))`.
`VeafCombatOperation:addTaskingOrder` calls `veafCombatZone.AddZone(zone)` on that same object, which inserts it into `veafCombatZone.zonesList` a second time.
Measured on "Marteau du Golan": the four members of OpMarteauGolan (EWRTellHara, KhanArnabah, ArtiKanaker, Sasa) were listed twice, and a loop activating every zone spawned them twice.

## What the second registration changed

- **`initialize()`: nothing.** `VeafCombatZone:initialize` returns at once when `self.initialized` is set, a guard added by FIX-IN-GAME-TEST-FINDINGS (2026-09-28) for the same pattern on the generated chain. The element lists and the radio menu are built once already.
- **`zonesDict`: nothing.** The same object is written under the same key.
- **`zonesList`: the defect.** The zone appears twice. Inside VMCT only `ActivateZoneNumber` / `DesactivateZoneNumber` read the list, by index, and the duplicates sit at its end; outside, BFR walks `zonesList` directly (`doc/mission-maker/custom-script-layer.md`), and so did mission-check's inventory.

## Change

The guard goes in `veafCombatZone.AddZone`, not in `addTaskingOrder`: it covers every caller, and `AddZone` owns the registry.

- A zone whose `missionEditorZoneName` is already in `zonesDict` (case-insensitive, like the dictionary) is not inserted again and not initialized again; `AddZone` returns the registered zone.
- A zone not yet registered is added and initialized as before — an operation may reference a zone the configuration did not add.
- A **different** zone object under a name already taken is a configuration error: logged as an error, the first zone kept. Before, the dictionary took the last one and the list held both.

## Tickets

- [01 — AddZone registers a name once](tickets/01-addzone-registers-a-name-once.md)
