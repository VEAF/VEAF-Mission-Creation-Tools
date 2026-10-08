# 07 — A convoy's smoke and call only for a side that has pilots

Status: ⬜ ready
Type: fix

## Found

David, 2026-10-08: the red assault convoy, once engaged, popped smoke as `veafGroundAI` intends, "peut-être une mauvaise idée pour les rouges".

`veafGroundAI.md` (*a convoy falling back calls for help*): red smoke on the nearest enemy, green on the convoy, renewed every 5 minutes, and a *troops in contact* call — in voice on 243 and 121.5 MHz AM when SRS is set up.
The smoke is meant for the convoy's own pilots.
In *Kolkhida* red has none, so the smoke only marks the red convoy for blue.

Also to check: whether the SRS call on the guard frequencies reaches the other side's pilots too.

## To do

- Pop the smoke, and send the call, only when the convoy's coalition has human pilots — read the connected players' sides at the time of the call, not a mission setting written once.
- Find out who hears the SRS guard call; if the enemy does, keep it to the convoy's side or say plainly that guard is heard by all.
- Lua tests: a red convoy with no red player pops no smoke and sends no call; with one red player, it does.
- Doc `veafGroundAI.md` FR + EN.

## Done when

A convoy of a side with no human pilot falls back without smoke and without a call; a side with pilots keeps both.
