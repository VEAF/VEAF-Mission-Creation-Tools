# 04 — An economy simulator to test the balance

Status: ✅ done
Type: feature

## Asked

David, 2026-11-20: a simulator to test the balance, "un peu comme notre projet Iron Gall".
Iron Gall's pacing report (`tools/Pacing`) plays virtual players against the real game core, headless: occasional, average and expert players, several strategies, several seeds; it gives the hour of each unlock and the money earned hour by hour (CSV), and `EditionTests` keeps the average player's milestones inside bounds.

## To do

- Run the real campaign Lua headless (`veafCampaign`, `veafCampaignEconomy`, `veafCampaignOps`, `veafCampaignLogistics`) on the DCS mocks of `test/lua/`, on a real campaign's data (Oronte, mission 1), advancing time by beats.
- Combat drawn from rates per virtual player, each with its source: kills by category, captures, deaths and ejections; calibrated on the logs of 2026-11-17 and 2026-11-19.
- Virtual teams and shop strategies; red plays its real decision code.
- A report: first purchase of each item, credits earned and spent per hour, red stock hour by hour and when red can no longer pay a SEAD or a raid; CSV.
- A guard test with bounds set from what the simulator measures after tickets 01-02.
- Docs FR and EN, CHANGELOG.

## Done (2026-11-20)

- `test/lua/campaign_sim.lua`: loads the real modules on `dcs_mocks.lua`, the framework's spawn data (`fixtures/veaf-spawn-data.lua`, the groups a garrison or an upgrade names) and the Oronte data of 2026-11-20 (`fixtures/oronte-campaign-data.yaml`, mission 1, with its airbases placed from `airdrome-positions.yaml`). It calls `veafCampaign.initialize()` and advances `dcs_mocks.currentTime` by `BEAT_SECONDS`, running the campaign's own scheduler.
- The players' war goes through the game's entry points: a DCS `S_EVENT_KILL` through `veafEventHandler` (unit, SAM, aircraft, building), the garrison's `onUnitLost`, `S_EVENT_EJECTION` and `S_EVENT_LAND` (held credits lost or banked), a CSAR delivery through `csar.rescuePilots` (the wrapper of ticket 01), the `delivered` notification for a supply crate, troops landed in an empty zone that the campaign's own clock captures, the shop's `buy` and `buyUpgrade`. The session's books of ticket 03 give the hour-by-hour earned and spent.
- Rates (`sim.RATES`), each with its source in the code: ground kills 1.2 a pilot-hour outside the captures' assaults (51 units an evening measured on 2026-11-17, assaults included), captures 2 an evening (measured), air kills, building kills, crate deliveries, deaths and rescues estimated, said so.
  Calibrated: with the rewards of before the lot, the average team earns 1,906 credits an evening for about 2,000 measured, and kills 56 ground units for 51 (`poetry run campaign-sim calibrate`, median of 5 seeds over 9 h).
- Teams (`sim.PLAYERS`): occasional (6 pilots, rates × 0.6), average (10, × 1), expert (10, × 1.6). Strategies (`sim.STRATEGIES`): `never`, `cheapest` (the cheapest item not bought yet, each once), `hawk` and `patriot` (save for it, then as `cheapest`).
- `poetry run campaign-sim report [hours] [seeds] [--csv path]` (`veaf_build/campaign_sim.py` runs `test/lua/campaign_sim_report.lua` with the tests' Lua); `poetry run campaign-sim fixtures` rewrites the fixtures, and `test/python/veaf_build/test_campaign_sim.py` fails when they drift from their sources.
- `test/lua/test_campaignEconomySim.lua` keeps three bounds (median of 3 seeds, about 18 s): the average team's first CAP between 1 h and 3 h with `cheapest` (measured 2 h 30), its Hawk between 1 h 30 and 6 h saving for it (2 h 50), red able to pay a SEAD for 45 minutes at least (1 h 00). It was checked to fail: a Hawk at 20,000 credits or a CAP at 6,000 is never bought.

### Run, not modelled

Every campaign module runs for real; none had to be modelled. What the mocks have no world for is modelled in `World`, and said in the code:

- the groups the campaign spawns: a flight is in the air at once for `AIR_LIFETIME` (1 h), a helicopter flies straight to its destination and lands there, a convoy drives straight to its destination at its speed;
- nothing shoots at the players' zones: red's strikes and assaults do no damage, so a players' zone never needs a resupply (the shop's `resupply` is refused);
- the virtual pilots sit high over the players' rear airfield: they are in a slot, and wake no zone, so the garrisons stay records (`onUnitLost` on a sleeping zone, as a kill far from the players does);
- the escort (it needs a player's group) and the tanker (an asset of the mission) are not bought;
- hours are hours of play, end to end: nothing runs between evenings;
- red's DCS behaviour after spawning (whether a CAP engages, a convoy fights) is not simulated, only what it costs.

## Measured (2026-11-20, `campaign-sim report 9 3`, median of 3 seeds)

| Team, strategy | First CAP | Hawk | Patriot | NASAMS |
|---|---|---|---|---|
| occasional, saving | — | 6 h 00 | not in 9 h | — |
| average, cheapest | 2 h 30 | — | — | 8 h 13 |
| average, saving | — | 2 h 50 | 7 h 02 | — |
| expert, saving | — | 2 h 05 | 4 h 23 | — |

- The average team earns about 2,600 credits an evening with the rewards of ticket 01, against 1,900 before (+38 %).
- Infantry, armour, Gepard and Avenger upgrades are bought in the first 50 minutes with `cheapest`: they cost 48 to 162 credits. It supports ticket 02's open question on their prices.
- **Red can no longer pay a SEAD or a raid from 1 h 00**, in every run: its first bomber raid (`bombers.seconds`, 3,600) costs 360 points and leaves the stock under a SEAD plus the reserve; it then hovers between 100 and 300 points, its reinforcements at spawn price spending most of what it makes. A question for David, not changed here: red's production, or the raid's cadence.
- Captures come to 1.3 an evening, not the 2 asked: red's helicopters and convoys contest or take back the neutral zones.

## In-game check

None: the simulator is a tool. Its rates are the thing to check against the next evenings' `ECONOMY SUMMARY` (ticket 03): if an evening's credits, kills or red spending move far from the simulator's, re-calibrate `sim.RATES` and the guard's bounds.
