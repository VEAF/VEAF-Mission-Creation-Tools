# 03 — The convoy that takes a zone becomes its garrison — find why it did not

Status: 🔄 in-progress — measurement shipped, cause not found

- **Shipped** (this lot): `absorbConvoy` logs every record it looks at — side, `ended`, what `Group.getByName` answers for its group, units alive and inside, the nearest unit's distance to the centre — and `capturedBy` logs when it falls back to drawing a garrison. Known limitation `a-captured-zone-may-draw-a-garrison-under-its-convoy`.
- **Read from the code, without result**: the mission flown at 16:02 ran the same `absorbConvoy` and `convoyUnits` as `develop` (same line numbers in its `veaf-scripts.lua` as in `dcs.log`); the group keeps its name through `veaf.addGroup`; the pathfinding unit's removal does not touch the group; the blue convoy had no contact, so no split nor merge; no other definition of `absorbConvoy` or `veafCampaign.convoys` in the bundle.
- **To do**: read the new `VEAF-CAMPAIGN` lines at the next capture by a convoy, then fix the condition they name, with a Lua test.

- First, **measure**: `absorbConvoy` logs, for every convoy record it looks at, why it is or is not absorbed (side, ended, unit count, nearest unit's distance to the centre); `capturedBy` logs which path it took.
- Reproduce on a test mission with time acceleration — a copy of the campaign in `D:\dev\_VEAF\_campaigns\campaign-kolkhida`, never David's live session — and read the new log lines at the capture. Hypotheses to rule in or out with that log, not to fix blind: the convoy group respawned or split at that instant (`veafGroundAI` arrival or resume), the record list or the record's side at that moment, `convoyUnits` returning nothing for a beat.
- Fix the cause found, with a Lua test that reproduces it. If the cause stays out of reach, keep the measurement and say so in the lot.
