# 01 — As many convoys as the players who can stop them

Status: ⬜ ready
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
