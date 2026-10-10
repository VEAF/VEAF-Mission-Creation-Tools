# Ready lots

[Back to the backlog](README.md)

Lots written up and ready to take.

### [FIX-OPEN-TRAINING-CAUCASUS-FINDINGS](FIX-OPEN-TRAINING-CAUCASUS-FINDINGS/PRD.md) · ⬜

What recompiling the Caucasus Open Training v6 in 6.29.0 found, each fixed by hand in the mission: no game master slot nor vehicle control in any v6 scaffold, a CTLD catalogue upgrade seen only in game, and no dashed line on the F10 map. Three tickets, one PR.

### [FIX-CONVOY-FROZEN-STANDOFF](FIX-CONVOY-FROZEN-STANDOFF/PRD.md) · ⬜

A convoy held at its standoff in front of an enemy DCS does not make it engage stays frozen for ever: its watch keeps the contact alive, so the quiet minute that relaunches it never comes. Measured on the *Kolkhida* test, 2026-10-10, 40 game minutes without a shot. Decided: with no fire exchanged for a while, it closes in.

### [ENRICH-DEFAULT-PRESETS](ENRICH-DEFAULT-PRESETS/PRD.md) · ⬜

Broaden the shipped default radio presets, after phase 1 of the radio preset projection.

### [FEAT-LIVE-GAME-MASTER](FEAT-LIVE-GAME-MASTER/PRD.md) · ⬜

Claude acting in a running mission while the squadron flies — spawn, destroy, move convoys, radio messages — through the bridge, with an operator token and never raw Lua. Written up 2026-10-08 and decided by David: free by default, nothing shown when Claude plays red, text and SRS voice when it warns blue players; seven tickets, one of them in the bridge's repository.
