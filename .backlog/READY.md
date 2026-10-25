# Ready lots

[Back to the backlog](README.md)

Lots written up and ready to take.

### [FEAT-GO-VEAF-LOGS-SHIP](FEAT-GO-VEAF-LOGS-SHIP/PRD.md) · ⬜

The release builds and publishes the Go `veaf-logs.exe` in place of the PySide6 one, which leaves; the Python core the support bot imports stays. Three tickets; first question: which Python stays and which side is the parity reference (ADR 0023).

### [FEAT-CLEAR-GROUND-COVERAGE](FEAT-CLEAR-GROUND-COVERAGE/PRD.md) · ⬜

Widen the shipped clear-ground catalogues to the places missions are built — round airfields, towns, road axes — under a weight ceiling per theatre. Needs a survey flown in DCS, so David's time; split from FIX-DEMO-VIDEO-FINDINGS (2026-10-23).

### [ENRICH-DEFAULT-PRESETS](ENRICH-DEFAULT-PRESETS/PRD.md) · ⬜

Broaden the shipped default radio presets, after phase 1 of the radio preset projection.

### [FEAT-LIVE-GAME-MASTER](FEAT-LIVE-GAME-MASTER/PRD.md) · ⬜

Claude acting in a running mission while the squadron flies — spawn, destroy, move convoys, radio messages — through the bridge, with an operator token and never raw Lua. Written up 2026-10-08 and decided by David: free by default, nothing shown when Claude plays red, text and SRS voice when it warns blue players; seven tickets, one of them in the bridge's repository.
