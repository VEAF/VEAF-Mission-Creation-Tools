# 01 — Rewards aligned on Foothold's

Status: ✅ done (in-game check pending)
Type: fix

## Decided

David, 2026-11-20 (a): the players' rewards take Foothold's values, already proven on its servers.

## To do

- `economy` defaults: a SAM destroyed 30 (a unit with `SAM SR`, `SAM TR` or `IR Guided SAM`, as Foothold reads it, or the attribute our ranking already uses for `SAM`), an aeroplane or a helicopter 50, a building 100 — any building of an enemy zone (a factory's, a depot's) destroyed by a player, not only by the sappers —, a pilot rescued 200 (a CSAR pick-up delivered to a friendly zone; credited to the rescuing pilot).
- Each a setting next to `kill_ground` and `kill_air`, so a campaign tunes it; the landing share (`landing_share`) applies to them as to the other kills.
- The player document's and `PERSISTENT_CAMPAIGN.md`'s reward table follow.
- Tests (TDD) per reward.

## Done when

A SAM, an aircraft, a building and a rescue each pay their new reward in the tests, and the in-game check is written.

## Done (2026-11-20)

- `veafCampaign.DYNAMIC_DEFAULTS.economy`: `kill_sam` 30, `kill_air` 50 (was 30), `kill_building` 100, `rescue` 200, next to `kill_ground` 10; the tools' validator (`dynamic_settings.py`) accepts the three new keys.
- A kill pays by its ranking figure (`veafCampaignEconomy.REWARD_OF_STAT`): `Air` and `Helo` pay `kill_air`, `SAM` pays `kill_sam`, a `Structure` pays `kill_building`, the others `kill_ground`.
  SAM is read as the ranking reads it (`killStat`: DCS attribute `SAM related` or `Air Defence`), so a SAM counted in the ranking is the SAM paid; it takes in the AAA guns, which Foothold pays as ground units (10). One definition rather than two.
- A building of a zone the enemy holds (a factory's, a depot's: `veafCampaign.structureIndex`) destroyed by a player pays `kill_building`, with the landing share, as any kill; the sappers' `economy.demolition` goes from 50 to 100, so a building is worth 100 whoever brings it down.
- A rescue: `veafCampaignEconomy.watchRescues` wraps the CSAR module's `csar.rescuePilots`, which delivers a helicopter's downed pilots once it has landed within 200 m of a MASH. The pilot of the players' side flying it earns `economy.rescue` per pilot delivered, in full — he is on the ground already, no share is held. An AI helicopter or the enemy's earns nothing; without the CSAR module, nothing is wrapped (logged).
  "Delivered to a friendly zone" is the CSAR module's own delivery, to a MASH: it is what tells a rescue apart from a pick-up.
- The theatre dossier's player guide gives the rewards (`reward_line`, `campaign.dossier.guide.rewards`), from `economy` over the defaults (`theatre_dossier.REWARDS`, checked against the Lua by a test).
- `PERSISTENT_CAMPAIGN.md` / `.en.md`: the rewards table, the sappers' 100, the settings line.
- Tests: `TestCampaignShop` — a SAM, a helicopter, a building (an enemy's pays, an own one or an AI kill does not), each reward a setting, a rescue per pilot and once, an AI or enemy rescue, no CSAR module; the tools' validator.

## In-game check

1. Fly a slot of the players' side; destroy a SAM radar of an enemy zone: the message says "+15", and 15 more at landing on a friendly base.
2. Shoot down an enemy helicopter: "+25", then 25 at landing.
3. Bomb a building of an enemy factory or depot: "+50", then 50 at landing; `dcs.log` shows `CREDITS <pilot> +50 (kill_held)`.
4. Eject over the enemy's side; fly a helicopter of the players' side to the downed pilot, pick him up, land at a MASH: the message "<pilot> brought 1 pilot(s) back to the MASH", +200, and `CREDITS <pilot> +200 (rescue)` in `dcs.log`.
