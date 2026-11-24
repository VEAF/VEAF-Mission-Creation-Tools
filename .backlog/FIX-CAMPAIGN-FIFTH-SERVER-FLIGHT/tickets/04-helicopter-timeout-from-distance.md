# 04 — A supply helicopter's timeout from its distance

Status: ✅ done
Type: fix

## To do

- First, a failing test: a supply helicopter sent 57 km (Bassel Al-Assad → Jisr al-Shughur) is still followed, not destroyed, 1300 s after it left; one still flying well past its own flight time fails.
- `veafCampaignOps.sendHelicopter`: record the helicopter's own timeout, from the distance between its start and its landing spot at `veafAircraftSpawn.HELICOPTER_SPEED`, times 1.5, plus 300 s for the start-up and the landing. `helicopter_timeout` becomes the floor of it, so a short hop keeps today's value.
- `followHelicopter` (`veafCampaignOps.lua` line 644) and `keepAwake` (lines 513 and in `veafCampaign.lua` line 2987) use the record's timeout. A record loaded from a save made before this change, with no timeout of its own, uses `helicopter_timeout`.
- Log the timeout when the helicopter leaves ("… leaves [Bassel Al-Assad] to resupply [Jisr al-Shughur], 57 km, timeout 41 min"), so a failure can be read against it.
- Tests: the timeout of a 57 km flight; of a 10 km hop (the floor); a helicopter still flying past its own timeout fails and is destroyed, as today; a saved record without a timeout.
- Docs: the campaign page where `helicopter_timeout` is described; CHANGELOG entry.

## Done when

A supply helicopter is removed only once it has had the time to fly its route, and no second one is sent on top of a helicopter still on its way; with tests.

## In-game check

On the Campagne server: a red supply helicopter from Bassel Al-Assad lands at Jisr al-Shughur (`supply helicopter [...] landed N m from [Jisr al-Shughur]'s centre`), and no `failed` line comes before it.

## Done (2026-11-22)

- `veafCampaignOps.helicopterTimeout(distance)`: `distance / HELICOPTER_SPEED × 1.5 + 300`, floored at `helicopter_timeout`; 57 km gives 2,437 s (41 min), 10 km the floor.
- `sendHelicopter` records `record.timeout` from its start to its landing spot, keeps the target awake that long, and logs `… leaves [Senaki] to capture [Poti], 50 km, timeout 37 min`.
- `followHelicopter` fails a helicopter still flying after `record.timeout`, or `helicopter_timeout` for a record with none. Helicopter records are not saved (a restart loses the helicopters in flight), so the fallback covers only a record built before the change.
- `veafCampaign.lua` line 2987 (`launchOffensives`) is the **convoy**'s keep-awake, not a helicopter's: it keeps using `helicopter_timeout`, as before. Left as it is, out of this ticket's fix.
- Tests: the timeout of 57 km and of 10 km; a helicopter on a 50 km route still followed at 1,300 s and failed at its own timeout; a record with no timeout uses the setting; the departure log line.
- Docs: the campaign page (FR/EN), `helicopter_timeout` described as the floor.
