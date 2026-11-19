# 07 — An assault convoy vanishes in front of the players when it is attacked

Status: 🧑 waiting-human — implemented, waits for the in-game check
Type: fix

## Found

dcs.log of the Campagne server, 2026-11-19: a player attacked the red convoy "Aleppo - Menagh assault", 3.9 km from Menagh.
The ground AI wrote `engage: convoy Bison: an assault under air attack drives on` about 15 times in one minute, once per hit, then at 21:00:14 the campaign wrote `retireConvoy: assault convoy [Aleppo - Menagh assault] to [Menagh] retired: it fell back under fire, 20 point(s) back`.
`retireConvoy` destroys the group: the convoy disappeared under the player's guns.
Added on David's decision, relayed by the controlling session on 2026-11-19.

## Cause

- The campaign reads the convoy watch's state (`ConvoyUnitHandler.STATE_FALLING_BACK`) once per beat, and retires on the first sample.
  Under fire the state changes at every hit: `engage` runs again whenever the convoy is not "in contact", and a hit that leaves it with no armed vehicle, or a threat it can answer, sets "falling back" for a moment between two "drives on".
- A retirement, whatever its reason (fall-back, timeout, target already taken), removed the convoy at once, players watching or not.
- "drives on" was logged at every hit, since every hit runs `engage` again.

## To do

1. A fall-back counts only when the convoy has been falling back for `fall_back_seconds` without a break, never on one sample.
2. A retirement waits until no player is within `wake_radius` of the convoy and it has not been in contact for `retire_quiet_seconds`. Until then it stays in play: the kills count, and the refund covers what is still alive when it is actually removed.
3. "drives on" is logged once per convoy and engagement.

## Done when

Tests show a fall-back sampled once does not retire a convoy, and a convoy waiting for its retirement while a player is near or it is under fire; the next evening, a convoy attacked by players stays until destroyed or out of their sight.

## Implemented (2026-11-19)

`veafCampaign.checkConvoyGoal` decides a retirement once (`record.retiring`, the route failure recorded then) and `convoyMayLeave` lets the convoy go only with no player within `wake_radius` and no contact (`lastContact`, `lastFireExchanged` of the convoy watch) for `retire_quiet_seconds` (300 s); a fall-back counts after `fall_back_seconds` (120 s) of `STATE_FALLING_BACK` without a break. `retireConvoy` is unchanged: it refunds the survivors at the moment it runs. The ground AI logs "drives on" once per engagement (`drivingOnSince`, `QUIET_DELAY`). Tests: `TestCampaignConvoyGoal` in `test_veafCampaignPersistent.lua`, `TestConvoyContact` in `test_veafGroundAI_convoy.lua`.
A convoy to retire keeps its place among `max_convoys` while it waits: with a player patrolling within 60 km, it may wait the whole evening.

## To check in game

1. Attack a red assault convoy from the air until it falls back or stops.
2. It stays on the map while you are within 60 km, and `dcs.log` writes `to retire (...) stays: a player near` once.
3. Fly away: about 5 minutes after the last hit, it is retired.
