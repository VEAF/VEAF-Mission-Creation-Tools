# Ready lots

[Back to the backlog](README.md)

Lots written up and ready to take.

### [FIX-SANCTUARY-WEAPON-TARGET-NO-ISEXIST](FIX-SANCTUARY-WEAPON-TARGET-NO-ISEXIST/PRD.md) · ⬜

12 `attempt to call method 'isExist' (a nil value)` in the Privé 1 log of the Sinai Open Training (2026-10-12): `weapon:getTarget()` returns an object with no `isExist`, the sanctuary guard raises and the shot is not recorded. Measure what the object is, then guard by what it can answer. One ticket.

### [ENRICH-DEFAULT-PRESETS](ENRICH-DEFAULT-PRESETS/PRD.md) · ⬜

Broaden the shipped default radio presets, after phase 1 of the radio preset projection.

### [FEAT-LIVE-GAME-MASTER](FEAT-LIVE-GAME-MASTER/PRD.md) · ⬜

Claude acting in a running mission while the squadron flies — spawn, destroy, move convoys, radio messages — through the bridge, with an operator token and never raw Lua. Written up 2026-10-08 and decided by David: free by default, nothing shown when Claude plays red, text and SRS voice when it warns blue players; seven tickets, one of them in the bridge's repository.
