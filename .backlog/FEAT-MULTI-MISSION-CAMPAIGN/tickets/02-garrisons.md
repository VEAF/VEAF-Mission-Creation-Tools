# 02 — Garrisons: drawn once, recorded, spawned from the state

Status: ⬜ ready

Shared brick: reused by `FEAT-DYNAMIC-CAMPAIGN`, which adds dormancy on top.

New runtime module `src/scripts/veaf/veafCampaign.lua` (`veafCampaign`, class `VeafCampaignZone`), loaded with the campaign's data table (the `veafCities.lua` model).

## The draw

- A zone with no recorded garrison draws one from its size class with `veafCasMission`'s generators, for the zone's owner and the mission's era — or takes its explicit `garrison` list.
- The drawn composition (unit types, and positions once placed) is **written to the state file** (ticket 05) and becomes the zone's garrison for every following mission: the draw happens once per owner, not once per mission.
- The generators currently spawn as they draw; this ticket separates *compose* from *spawn* in `veafCasMission` without changing what CAS missions get (their tests stay green).

## The spawn

- At mission start, every garrison is spawned from the state **minus its losses**: a SAM site that lost two launchers starts without them.
- Placement through `veaf.findSpawnPoint` (automatic, David 2026-10-03); the position found is recorded, so the site stands at the same place next mission.
- Losses come from `S_EVENT_DEAD` / `S_EVENT_UNIT_LOST`, recorded against the garrison entry.
- A zone whose whole garrison is destroyed turns **neutral** and announces it.

## Open question, decided while writing

The first mission's briefing needs garrisons the mission has not drawn yet.
Either the briefing speaks in intelligence terms ("estimated strength") until a mission has run, or `campaign init` runs the draw in Python from the same tables — which means one copy of `veafCasMission`'s tables readable by both sides (extracted to data, as `veaf-units.yaml` is).
The second is the cleaner one if the extraction is mechanical; measured before choosing.

## Done when

luaunit tests with the DCS mocks: draw only when no garrison is recorded, explicit list wins, recorded composition respawned identically, losses subtracted, whole garrison lost → neutral, CAS mission output unchanged; `luacheck`, `stylua`, Lua coverage floor raised.
