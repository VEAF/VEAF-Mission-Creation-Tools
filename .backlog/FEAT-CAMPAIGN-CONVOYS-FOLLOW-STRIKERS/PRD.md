# FEAT-CAMPAIGN-CONVOYS-FOLLOW-STRIKERS — the enemy's assault convoys sized for the players who can stop them

Status: ✅ done — merged in #1324 (2026-11-21), on `develop` with #1336 (2026-11-23), shipped in 6.39.0

Flight check: on the Campagne server, with one to four ground-attack players `dcs.log` never shows two `red assault convoy [...] left` without a `destroyed`, `arrived` or retirement between them; an air-to-air-only or AGM-88-only aircraft is not counted; a counter-attack skips a zone a striker defends (tickets 01 and 02's in-game checks).

Griffin, relayed by David on 2026-11-21: "ça serait chouette d'adapter le nombre et la fréquence des colonnes ennemies qui partent capturer des points en fonction des forces bleues en présence. Hier on était 3 et il y avait en permanence au moins deux convois rouges à aller intercepter. Du coup, on ne peut pas aller attaquer une base rouge sans laisser se faire capturer au moins deux points bleus."

## Measured (Campagne server, 2026-11-20, 20:30 to 22:34 UTC, 3 players)

| Left (UTC) | Convoy | Road | End |
|---|---|---|---|
| 20:30 | Jisr al-Shughur → Hatay (counter-attack) | 75 km, about 120 min | destroyed at 22:08, 19 km from Hatay |
| 20:45 | Afrin → Kilis (counter-attack) | 41 km, about 69 min | standing still 12 km from Kilis from 21:45; still there at the end, kept because a player was near |
| 21:33 | Taftanaz → Afrin (assault on a neutral zone) | 70 km, about 112 min | 42 km from Afrin at the end |

No convoy took a zone, but the players had to watch three of them all evening.

The three causes, in `veafCampaign.lua`:

1. `max_convoys` is 2 whatever the number of players; `launchOffensives` sends a counter-attack every `attack_seconds` (900) as soon as a place is free.
2. A convoy is on the road 70 to 120 minutes, so a place is almost never free: the cap holds all evening, and `attack_seconds` hardly matters.
3. `planAssaults` (an assault on a neutral zone) does not count against `max_convoys`: the third convoy.

`veafOpposition.getLevel()` already follows the players, but only `assaultDelay()` reads it, and only above 4.

## Decided

David, 2026-11-21:

- **a.** The number of convoys on the road follows the number of players **who can stop a convoy**: strikers, CAS aircraft, attack helicopters. A fighter armed for air-to-air only, or a SEAD aircraft carrying anti-radiation missiles only, does not count. Ticket 01.
- **c.** A counter-attack prefers a zone the players are not defending, so they choose between defending and attacking. Ticket 02.

Not taken: a longer `attack_seconds` with few players (b): the cap holds all evening, the delay would change nothing.

Defaults (estimates, to tune after two evenings with the evening's balance of FIX-CAMPAIGN-ECONOMY-BALANCE ticket 03): one convoy per 4 such players, rounded up, at least 1, at most `max_convoys`, raised to 3.

The integration branch is `feature/dynamic-campaign`: one branch and one pull request into it.

| # | Ticket |
|---|---|
| 01 | [As many convoys as the players who can stop them](tickets/01-convoys-follow-ground-attack-players.md) (a) |
| 02 | [A counter-attack goes where the players are not](tickets/02-counter-attack-avoids-the-players.md) (c) |
