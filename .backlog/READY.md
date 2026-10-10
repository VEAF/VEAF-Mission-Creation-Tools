# Ready lots

[Back to the backlog](README.md)

Lots written up and ready to take.

### [FIX-SECURITY-GROUP-LEVEL](FIX-SECURITY-GROUP-LEVEL/PRD.md) · ⬜

Every secured `+` radio command is refused to every pilot whenever security is on, since 6.14.0: the group's level is computed through `Group.getByID`, which DCS does not have, so no occupant is ever found and the group is level 0. Measured on `private1` on 2026-10-10 with a level-99 pilot. Also: `/secu elevate`, which the refusal suggests, does not exist when `SECURITY` is not listed. Needed for *Kolkhida* mission 2 on 2026-10-15.

### [FIX-CONVOY-FROZEN-STANDOFF](FIX-CONVOY-FROZEN-STANDOFF/PRD.md) · ⬜

A convoy held at its standoff in front of an enemy DCS does not make it engage stays frozen for ever: its watch keeps the contact alive, so the quiet minute that relaunches it never comes. Measured on the *Kolkhida* test, 2026-10-10, 40 game minutes without a shot. Decided: with no fire exchanged for a while, it closes in.

### [ENRICH-DEFAULT-PRESETS](ENRICH-DEFAULT-PRESETS/PRD.md) · ⬜

Broaden the shipped default radio presets, after phase 1 of the radio preset projection.

### [FEAT-LIVE-GAME-MASTER](FEAT-LIVE-GAME-MASTER/PRD.md) · ⬜

Claude acting in a running mission while the squadron flies — spawn, destroy, move convoys, radio messages — through the bridge, with an operator token and never raw Lua. Written up 2026-10-08 and decided by David: free by default, nothing shown when Claude plays red, text and SRS voice when it warns blue players; seven tickets, one of them in the bridge's repository.
