# 03 — `-escort` and *Escort me*

Status: ✅ done — on the mocks; the in-game reading is ticket 04

Lot: [FEAT-AWACS-ESCORT-COMMANDS](../PRD.md)

#189, reshaped by David on 2026-10-04: the marker escorts the airplane it is placed next to, and the F10 menu escorts the pilot's own group.

## Done when

- `_spawn escort, name <template>` / `-escort <template>` escorts the friendly or neutral airplane nearest the marker, within 10 NM; an enemy one is never chosen; nothing near says so.
- *F10 → VEAF → SPAWN → +Escort me (fox3)* and *(fox2)*, per group, at the known-pilot level a `-cap` marker asks for; a helicopter is refused. `veafSpawn.EscortRadioMenuTemplates` sets the entries.
- Tests in `test_veafAwacsEscort.lua` (`TestEscortCommands`).
