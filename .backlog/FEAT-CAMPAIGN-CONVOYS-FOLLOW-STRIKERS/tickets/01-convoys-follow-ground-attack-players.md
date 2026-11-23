# 01 — As many convoys as the players who can stop them

Status: ✅ done
Type: feature

## Decided

David, 2026-11-21 (option a, with his rule on who counts): count the players who can stop a convoy — strikers, CAS aircraft, attack helicopters — not a fighter armed for air-to-air only, nor a SEAD aircraft with anti-radiation missiles only.

## To do

- A predicate next to `veafOpposition.armedForAirToAir`, e.g. `veafOpposition.armedForGround(unit)`, read with `getAmmo` (what the aircraft carries now, the loadout chosen at rearming): true when the unit carries, with a count above 0,
  - a bomb (`Weapon.Category.BOMB`) or a rocket (`Weapon.Category.ROCKET`);
  - a missile that is neither air-to-air (`Weapon.MissileCategory.AAM`) nor anti-radiation (guidance `Weapon.GuidanceType.RADAR_PASSIVE`: HARM, Shrike, ALARM, Kh-58…): Maverick, Hellfire, Vikhr, JSOW, SLAM, Kh-25ML, glide bombs carried as missiles.
  The gun and gun pods do not count: every fighter has one. A helicopter therefore counts when it carries rockets or anti-tank missiles; a transport helicopter with door guns does not.
  Read the real `desc` values of a HARM, a Maverick, a Hellfire, an APKWS and a GBU in game (or in `dcs-world-schema`) before trusting the categories above, and write what was measured in the code comment.
- A count of those players in a slot (in the air or on the ground: a striker on the ramp is about to fly), among the players' side (`veafOpposition.countPlayers` gets a third filter, or a sibling).
- The cap on an enemy side's convoys on the road: `ceil(count / players_per_convoy)`, at least 1, at most `max_convoys`. New setting `players_per_convoy` (4); `max_convoys` default 2 → 3. Both in the tools' validator (`dynamic_settings.py`) and `PERSISTENT_CAMPAIGN.md` / `.en.md`.
- `planAssaults`'s convoys (to a neutral zone) count against the same cap: an assault due when the cap is reached waits for a free place instead of leaving.
- A convoy already on the road stays when players leave or change loadout: the cap only decides whether a new one leaves.
- A `[CAMPAIGN DECISION]` debug line when a convoy does not leave because of this cap, with the count and the cap ("red does not counter-attack: 1 convoy on the road, 3 ground-attack players → 1").
- Tests (TDD): the predicate on each family (bombs, rockets, AGM, ATGM, AAM only, ARM only, ARM + bombs, gun only, empty); the cap at 0, 3, 4, 5, 9 players and with `max_convoys`; a neutral-zone assault held by the cap; a convoy on the road kept when the count drops.
- The simulator (FIX-CAMPAIGN-ECONOMY-BALANCE ticket 04) keeps passing; if it counts convoys, its bounds follow.

## Done when

With 3 players, of whom any number fly CAP or SEAD only, red has one assault convoy on the road at most, neutral-zone assaults included; with 9 ground-attack players, 3; with tests.

## In-game check

1. On the Campagne server, 1 to 4 players in a slot with bombs, rockets or air-to-ground missiles: `dcs.log` never shows two `red assault convoy [...] left` without a `destroyed`, `arrived` or retirement between them.
2. A player in an F/A-18C with AIM-120 and AIM-9 only, or an F-16C with AGM-88 only, is not counted: the decision line gives the count without him.
3. Five ground-attack players: a second convoy can leave.

## Done

2026-11-21, branch `feature/campaign-convoys-follow-strikers`.

- `veafOpposition.armedForGround(unit)`: a bomb or a rocket, or a missile neither `AAM` nor guided `RADAR_PASSIVE`, with a count above 0; shells (gun, gun pods) do not count. `veafOpposition.groundAttackPlayers(coalitionId)` lists those players, airborne or not.
- Measured in the game's weapon files (`CoreMods/aircraft/AircraftWeaponPack`, 2026-11-21; DCS was not running, so not read with `getAmmo` in game): the GBU-12 is a `wsType_Bomb`; the AGM-65D, the AGM-114K and the APKWS (`AGR_20_M282`) are `wsType_AS_Missile` — the APKWS is a missile, not a rocket —, with TV, laser and laser heads; the AGM-114L has an active radar head, which is why the rule tests `missileCategory` and not the guidance for everything but ARMs; the AGM-88 has the passive radar head (`Head_Type = 3`). The files' head numbers are not the scripting enum's (AIM-9 1, AIM-120 2, AIM-7 6), so the mapping of the HARM's head to `Weapon.GuidanceType.RADAR_PASSIVE` is to confirm in game; it is written in the code comment.
- `veafCampaign.convoyCap(side)`: `ceil(count / players_per_convoy)`, at least 1, at most `max_convoys`, counting the other coalition's ground-attack players; without `veafOpposition` loaded, `max_convoys`. `veafCampaign.convoyRoom` holds a new convoy when the cap is reached and logs `[CAMPAIGN DECISION] red does not counter-attack: 1 convoy(s) on the road, 3 ground-attack player(s) → 1` once per change.
- `launchOffensives` and, in a persistent campaign, `launchDueAssaults` (neutral-zone assaults) go through it; a held assault stays pending and leaves when a place is free. A convoy on the road is never taken off for the cap.
- Settings: `players_per_convoy` (4), `max_convoys` 2 → 3, in `DYNAMIC_DEFAULTS`, `dynamic_settings.py` and `PERSISTENT_CAMPAIGN.md` / `.en.md`.
- Tests: the predicate on each family (`test_veafOpposition.lua`); the cap at 0, 3, 4, 5, 8, 9 and 20 players, `max_convoys`, fighters and ARM-only aircraft, 3 and 5 players, a convoy kept when the players leave, a neutral-zone assault held and counted (`test_veafCampaignPersistent.lua`). The economy simulator passes unchanged.
