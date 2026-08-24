# 01 — brief whoever is already flying

Status: ✅ done

Part of [FIX-WELCOME-BRIEF-NEVER-FIRES](../PRD.md).

Subscribe to `S_EVENT_BIRTH` as well as `S_EVENT_PLAYER_ENTER_UNIT`, guard on the unit being human, and
**sweep the already-occupied human slots** at initialization — because in single player the event has
already fired before this module loads.

Done when a pilot taking a slot at mission start gets his brief, in single player, on an airfield and on a
carrier, and when reverting either half of the wiring fails a test.
