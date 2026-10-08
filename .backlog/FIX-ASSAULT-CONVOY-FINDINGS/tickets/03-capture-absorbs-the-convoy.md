# 03 — The convoy that takes a zone becomes its garrison — find why it did not

Status: ⬜ ready

- First, **measure**: `absorbConvoy` logs, for every convoy record it looks at, why it is or is not absorbed (side, ended, unit count, nearest unit's distance to the centre); `capturedBy` logs which path it took.
- Reproduce on a test mission with time acceleration — a copy of the campaign in `D:\dev\_VEAF\_campaigns\campaign-kolkhida`, never David's live session — and read the new log lines at the capture. Hypotheses to rule in or out with that log, not to fix blind: the convoy group respawned or split at that instant (`veafGroundAI` arrival or resume), the record list or the record's side at that moment, `convoyUnits` returning nothing for a beat.
- Fix the cause found, with a Lua test that reproduces it. If the cause stays out of reach, keep the measurement and say so in the lot.
