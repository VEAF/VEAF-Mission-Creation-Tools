# Ready lots

[Back to the backlog](README.md)

Lots written up and ready to take.

### [FIX-OPENCODE-TEST-FINDINGS](FIX-OPENCODE-TEST-FINDINGS/PRD.md) · ⬜

What David's end-to-end OpenCode test on 6.31.1 met (2026-10-20, 161 minutes, 162 shell calls): the self-update replacing the exe under running servers, `edit_mission_file` failing on CRLF, reference data only readable inside the exe, presets and FARP slots to investigate, heavy reads, and no action to check a built `.miz`. One lot, one PR, released as 6.31.2; absorbs FEAT-INSPECT-BUILT-MISSION.

### [ENRICH-DEFAULT-PRESETS](ENRICH-DEFAULT-PRESETS/PRD.md) · ⬜

Broaden the shipped default radio presets, after phase 1 of the radio preset projection.

### [FEAT-LIVE-GAME-MASTER](FEAT-LIVE-GAME-MASTER/PRD.md) · ⬜

Claude acting in a running mission while the squadron flies — spawn, destroy, move convoys, radio messages — through the bridge, with an operator token and never raw Lua. Written up 2026-10-08 and decided by David: free by default, nothing shown when Claude plays red, text and SRS voice when it warns blue players; seven tickets, one of them in the bridge's repository.
