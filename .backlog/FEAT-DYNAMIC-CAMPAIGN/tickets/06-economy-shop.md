# 06 — Coalition credits and a small shop

Status: 🧑 waiting-human — code and tests done on `feature/dynamic-campaign-v1` (2026-11-15); the in-game check of the test mission is David's

Analysis note 05 §1–§2, §5. Coalition credits only: personal credits, ranks and career are V2.

## Credits

- One account for the players' side, saved with the campaign (ticket 01); starts at `economy.start_credits` (500).
- Earned by: a kill by a player (`economy.kill`: 10 a ground unit, 30 an aircraft), a capture (`economy.capture`: 200), a supply delivery (`economy.delivery`: 100), a task done (ticket 07).
- Every gain is told to the side in one short line, with the new balance.

## Shop (Campaign → Shop)

Six to eight items, each an effect VEAF already has; each item lists the zones it applies to, paginated by `veafRadio`.

| item | effect | built on |
|---|---|---|
| JTAC drone | an MQ-9 over an enemy zone, lasing; also reveals the zone (ticket 08) | `veafSpawn.spawnAFAC` |
| Illumination | illumination flares over a zone | `veafSpawn.spawnIlluminationFlare` |
| Smoke | red smoke on three live units of an enemy zone | `veafSpawn.spawnSmoke` |
| Friendly CAP | a CAP of the players' side over one of its zones | ticket 05's aircraft, `zone_defense` |
| Tanker | the campaign's tanker asset respawned (only when `economy.tanker` names one) | `veafAssets.respawn` |
| Intel | the composition of an enemy zone for 60 min (ticket 08) | ticket 08 |
| Capture | a supply helicopter sent to a neutral zone | ticket 04 |
| Resupply | a supply helicopter sent to a damaged zone | ticket 04 |

Prices in `economy.prices`, defaults in the module; an item refused (no target, nothing in reach) costs nothing.

## Done when

Lua tests: gains per event, balance never below zero, purchase refused for lack of credits, refused item free, saved and reloaded.
In game: kill a unit, the balance rises; buy illumination over a zone.

## As built

The settings are under `dynamic.economy`; the kill reward is split in `kill_ground` (10) and `kill_air` (30).
