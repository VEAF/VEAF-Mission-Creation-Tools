# FIX-CAMPAIGN-MISSION-1-FINDINGS — what the squadron found flying *Kolkhida* mission 1

Status: 🧑 waiting-human

Origin: *Kolkhida* mission 1 (`Kolkhida_20261008.miz`, built by veaf-tools `6.28.1-kolkhida7`), flown by the squadron on `private1` (dcs.veaf.org) on 2026-10-08, from 21:23 to about 23:00 server local time.
Claude followed the server's `dcs.log` over SSH all evening; David reported what the players saw.

The evidence is kept with the campaign, in `D:\dev\_VEAF\_campaigns\campaign-kolkhida\missions\mission-01\`: `dcs-private1-2026-10-08.log` (972 KB) and the last `mission-01.state` (23:00, identical to its `.tmp`).
The server keeps neither for long.

Mind the clocks: `dcs.log` stamps lines in **UTC**, the server's clock and its file times are local time, **UTC+2**.
A log line at 20:44 happened at 22:44 on the state file's clock.

## What the evening settled

- **No VEAF or Lua error, no warning**, from the mission's load to its last state write.
  The only `ERROR` lines are DCS's own model warnings at load (`No property record for cell…`), unrelated.
- **`FIX-CAPTURE-ZONE-MEMBERSHIP` ticket 01 holds in game.**
  At 20:44:44 UTC the blue assault convoy took Poti (`9 unit(s) alive, 9 inside, nearest 2123 m from the centre (radius 2000)`) and became its garrison; no garrison was drawn from the reserve.
  That is what David saw as "Poti a été pris mais pas de spawn de défense": the specified behaviour (`CAMPAIGN.md`, *in flight*), not a defect.
- **`FIX-CAPTURE-ZONE-MEMBERSHIP` ticket 02 does not hold.**
  The convoy's road ends 163 m from Poti's centre (`logRoadEnd`, 19:29:15 UTC), yet in both the 22:45 and the 23:00 state files its units stand 2 123 to 2 182 m from the centre: halted at the zone's edge again, like the earlier run.
  Whether the state file records live positions or the positions at absorption is to be checked before reading this as "it never drove on".
  The measurement goes to that lot's ticket 02.
- **`campaign apply` on the last state file**, run on a copy of the campaign (the real one is untouched), writes a sensible debriefing: Poti neutral → blue; blue lost 1 Patriot ECS at Batumi; red lost 10 (9 at Senaki, mostly S-300PS launchers and its 64H6E radar, 1 Chieftain of its convoy); 78 scenery objects destroyed.

## The defects it found

| # | Ticket | Status |
|---|---|---|
| [01](tickets/01-radio-presets-and-kneeboard.md) | Every aircraft gets its radio presets and the right kneeboard | ✅ |
| [02](tickets/02-atc-silenced.md) | A campaign mission silences the ATC | ✅ |
| [03](tickets/03-garrisons-keep-off-the-runways.md) | An airfield garrison keeps off the runways | ✅ |
| [04](tickets/04-qra-takes-off-from-the-ground.md) | A QRA takes off from the ground by default | 🧑 |
| [05](tickets/05-ctld-at-the-airfields.md) | CTLD crates and troops at the blue airfields | 🧑 |
| [06](tickets/06-objective-waypoints-on-the-ground.md) | Objective waypoints sit on the ground | ✅ |
| [07](tickets/07-convoy-smoke-only-for-a-side-with-pilots.md) | A convoy's smoke and call only for a side that has pilots | ✅ |
| [08](tickets/08-server-rewrites-date-time-weather.md) | The server rewrote the mission's date, time and weather | 🧑 |
| [09](tickets/09-escort-me-silent.md) | "Escort me" in an A-10C answered nothing | 🧑 |
| [10](tickets/10-campaign-flies-with-server-security.md) | A campaign mission flies with the server's security | ✅ |

04 depends on 03: a unit on Senaki's runway would keep the QRA on the ground.

## Decided

- **A QRA takes off from the ground by default** (David, 2026-10-08: "QRA au sol, par défaut"); an air start only when asked. Ticket 04.

## One PR

All ten tickets ship in one branch and one PR.
Each ticket reads the code before choosing a fix; what needs DCS is gathered into one test mission (a copy of the campaign, never David's live session) for David to run.
The in-game checks are R47 in `DCS-SESSION-TODO.md`, CTLD first.

## Related

- `FIX-CAPTURE-ZONE-MEMBERSHIP` — ticket 01 confirmed, ticket 02 measured again (above).
- `FEAT-CAMPAIGN-OBJECTIVE-WAYPOINTS` — the objective waypoints ticket 06 lowers.
- `FEAT-CTLD-AIRBASE-LOGISTICS` (done) — the airfield logistic zones ticket 05 looks at.
- `FEAT-CONVOY-UNDER-FIRE` — the convoy's call for help ticket 07 restricts.
