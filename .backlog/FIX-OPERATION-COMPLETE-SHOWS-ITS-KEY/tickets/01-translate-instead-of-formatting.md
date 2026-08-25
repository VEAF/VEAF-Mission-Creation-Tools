# 01 — translate the message instead of formatting its key

Status: ✅ done

Part of [FIX-OPERATION-COMPLETE-SHOWS-ITS-KEY](../PRD.md).

`veafCombatZone.lua:2041` — replace `string.format(<key>, name)` with `veaf.t(<key>, name)`, matching the
correct call at `:2143`.

Done when a completed operation's briefing contains its friendly name and no `combatzone.` key, and when
reverting the change fails a test.
