# Ready lots

[Back to the backlog](README.md)

Lots written up and ready to take.

### [ENRICH-DEFAULT-PRESETS](ENRICH-DEFAULT-PRESETS/PRD.md) · ⬜

Broaden the shipped default radio presets, after phase 1 of the radio preset projection.

### [FEAT-AIRWAVES-QRA-MERGE](FEAT-AIRWAVES-QRA-MERGE/PRD.md) · ⬜

Rebuild QRA on AirWaves instead of beside it (~120 KB of neighbouring Lua), closing six AirWaves issues in one design. A design lot before any refactor.

### [FEAT-DYNAMIC-CAMPAIGN](FEAT-DYNAMIC-CAMPAIGN/PRD.md) · ⬜

A Foothold-like persistent campaign built on VMCT alone, declared in a `campaign.yaml` sidecar from which the build generates zones, slots and data.

### [FEAT-MISSION-RECIPES](FEAT-MISSION-RECIPES/PRD.md) · ⬜

Scripted mission generation with no AI in the loop: a recipe file of MCP actions run by `veaf-tools`; the demo mission regenerated in CI would become the end-to-end test. Start with one recipe.

### [FEAT-PORTABLE-PREFABS](FEAT-PORTABLE-PREFABS/PRD.md) · ⬜

A design lot: bundle mission content (groups, statics, zones, media, mod dependencies) and re-instantiate it elsewhere. Rejecting the idea is an acceptable outcome.

### [FEAT-SPOTTER-DEMO-MISSION](FEAT-SPOTTER-DEMO-MISSION/PRD.md) · ⬜

A mission that proves a spotter report reaches a battery that never saw the aircraft. Tickets 01–04 done (durable history, rig, smoke-test suite); the demonstration layer is left.
