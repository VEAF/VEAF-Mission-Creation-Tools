# 02 — Runtime: zones, garrisons, dormancy, F10, radio

Status: ⬜ ready

New module `src/scripts/veaf/veafCampaign.lua` (`veafCampaign`, class `VeafCampaignZone`).

## Zone state

`side` (blue / red / neutral), `garrison` (the drawn composition, one entry per group with its losses),
`materialized` (units present in the world or not), `capture` (in progress or not — ticket 03).

## Garrisons

- Drawn once per owner change from the size class, through the VEAF group database filtered by era; the
  explicit `garrison` list wins when present.
- Spawned with the VEAF spawn path and `veaf.findSpawnPoint` (placement automatic, David 2026-10-03).
  If the in-game test shows it failing somewhere, hand-placed sub-zones become an optional per-zone
  fallback in `campaign.yaml`.
- Losses come from `S_EVENT_DEAD` / `S_EVENT_UNIT_LOST`, recorded against the garrison entry.
- A zone whose garrison is entirely destroyed turns **neutral** and announces it.

## Dormancy

A zone materializes when a player aircraft comes within a radius and dematerializes when none has been
near for a delay; its losses survive the round trip. The total of materialized groups is capped: the zones
nearest players win. Radius, delay and cap are **settings with conservative defaults**, not measured on a
workstation (David, 2026-10-03: the mission runs on our servers) — they are tuned after ticket 07's reading.

## One loop

A single `veafScheduler` loop processes a slice of zones per pass; no per-zone timer. The module keeps
**work counters** (zones processed, groups materialized, spawns, events handled) readable by admins from
the radio menu. Not a timing: the mission side has no wall clock (`os` is sanitized, and `timer.getTime`
is simulation time, frozen while a chunk of Lua runs) — timing is the DCSServerBot profiler's job.

## Map and radio

- F10: one filled circle per zone coloured by owner, one line per connection, redrawn on change only.
- Radio: a "Campaign" menu listing zones with owner, garrison strength (%), capture in progress.

## Done when

luaunit tests with the DCS mocks cover the state machine (draw, loss, neutral, dematerialize keeps losses,
cap respected), `luacheck` and `stylua` clean, the Lua coverage floor raised. One in-game reading
(DCS-SESSION-TODO): garrisons appear and disappear with a player's approach, and land where they should on
Caucasus, Syria and Persian Gulf.
