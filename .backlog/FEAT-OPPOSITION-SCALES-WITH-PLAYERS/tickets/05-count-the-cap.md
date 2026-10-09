# 05 — Count the players flying CAP, and set the level in one click

Status: ✅ done on the mocks — #1115, the demo's opposition step in VEAF-Demo-Mission-v6#7; `getAmmo` on a player aircraft left to R46 item 8

David, 2026-10-09, after flying *Kolkhida* mission 1 with the level following the players connected: "tous ces joueurs ne sont pas partis pour faire de la CAP, donc l'opposition est trop forte. On pourrait ajouter un menu radio pour le réglage manuel (avec des options du genre 1-2-3-4-5-6 joueurs en CAP), mais si t'as une meilleure idée je prends" — then "option c": both.

`follow: players` counts every blue player connected — `coalition.getPlayers` returns helicopters and ground-attack aircraft alike — so an evening of six with two on CAP got the opposition of six.

- **A follow mode `air_to_air`**: the level counts the players airborne carrying at least one radar-guided air-to-air missile (Fox 1 or Fox 3: `Weapon.MissileCategory.AAM`, guidance `RADAR_ACTIVE` or `RADAR_SEMI_ACTIVE`), read with `unit:getAmmo()` at each beat — what the aircraft carries now, whatever the pilot chose at rearming, not the mission's preset. An A-10 or a helicopter does not count, nor a bomb truck with two AIM-9; a Fox 2-only fighter does not either (said in the doc).
- **`campaign next` writes `follow: air_to_air`.**
- **The radio menu sets the level in one click**: Opposition → *Level* → 1 … 8 players on CAP (fixed), and Opposition → *Mode* → air-to-air / players connected / players airborne / fixed. The +1 / −1 entries go.

## Done when

Lua tests: a fighter with an AIM-120 counts, one with two AIM-9 only does not, a helicopter does not, a player on the ground does not, the count follows a rearm; the menu entries set the level and the mode. Python: the `follow` value is accepted, `campaign next` writes it. Doc, CHANGELOG, the demo's opposition step.
