# 01 — one lookup that complains

Status: ✅ done

Part of [FIX-GROUNDAI-SILENT-REFUSALS](../PRD.md).

Add `veafGroundAI.getOrComplain(name)`: `veafGroundAI.get` plus a message to the player when there is no
such autopilot. Use it in the six verbs that currently do `if handler then … end` with no `else`
(`unset`, `start`, `stop`, `clear`, `status`, `order`). Leave `set` alone — it creates the handler.

Then make `ArtilleryUnitHandler:orderTextAnalysis` announce an order text it cannot parse at all.

Done when each of the six verbs, given a name nobody registered, puts a message on screen naming that name
and the `_ground set` that would create it — and when a test per verb fails if it stops doing so.
