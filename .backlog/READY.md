# Ready lots

[Back to the backlog](README.md)

Lots written up and ready to take.

### [FIX-COMBATMISSION-MENU-MISSING](FIX-COMBATMISSION-MENU-MISSING/PRD.md) · ⬜

The generated config calls `veafCombatMission.initialize()` before adding the missions, so the MISSIONS radio menu is never built; wanted in 6.28.0.

### [FIX-DEMO-RECETTE-FINDINGS](FIX-DEMO-RECETTE-FINDINGS/PRD.md) · ⬜

Three defects the demo's first bridge recette found: `_destroy, radius` spares units it has already found, untranslated fog commands, the CAS group name stuck to « Blue CAS Group ».

### [ENRICH-DEFAULT-PRESETS](ENRICH-DEFAULT-PRESETS/PRD.md) · ⬜

Broaden the shipped default radio presets, after phase 1 of the radio preset projection.

### [FEAT-DYNAMIC-CAMPAIGN](FEAT-DYNAMIC-CAMPAIGN/PRD.md) · ⬜

A Foothold-like persistent campaign built on VMCT alone, declared in a `campaign.yaml` sidecar from which the build generates zones, slots and data.
