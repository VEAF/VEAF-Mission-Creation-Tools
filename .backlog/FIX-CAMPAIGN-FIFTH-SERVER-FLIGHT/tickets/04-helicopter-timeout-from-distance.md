# 04 — A supply helicopter's timeout from its distance

Status: ⬜ ready
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
