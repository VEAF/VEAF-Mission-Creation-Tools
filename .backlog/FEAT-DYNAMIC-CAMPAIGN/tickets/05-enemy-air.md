# 05 — Enemy air: CAP over the front, CAS and SEAD strikes, Hunter

Status: ✅ done

Replaces the former "AI sorties derived from the graph" for the air (the ground sorties are tickets 03 and 04).
No Director (David, 2026-11-15): a simple target rule, scaled by the number of players (analysis note 03 §2–§5, §8; note 04 §2, §4).

## Aircraft

Declared per side in `campaign.yaml` (`air.<side>.cap|cas|sead: { type, loadout, count }`), with shipped defaults per era; the build resolves each loadout **by name** from the DCS payloads the tools ship (`dcs_payloads`), and the validation refuses an unknown type or loadout.
So nothing depends on templates in the `.miz`.

## Sorties

- **CAP**: as long as fewer than the wanted number fly, a CAP is sent over the front zone of its side nearest the enemy players, with `veafAircraftSpawn`'s `zone_defense` role (the race-track and the CAP watchdog already read in game).
- **CAS / SEAD**: every `air.strike_seconds` (900 s), a strike on the enemy zone connected to the side's territory with the most units (CAS) or the most air defence (SEAD), with a new `campaign_strike` role: air start over the source airfield, `EngageTargetsInZone` on the target's circle with the target types of the role, an orbit of 10 minutes there, then land at the source.
- They take off from the nearest airfield zone of their side; none, no sortie.
- How many: the wanted CAP count and the strike cadence follow `veafOpposition`'s level, the number the mission is sized for (two players: 1 CAP; eight: 3), so a quiet evening is quiet.
- Caps: `air.max_flights` (4) per side in the air at once.

## Hunter

A player of the players' side who kills `hunter.kills` (8 ground or 4 air, drawn once per life between those and their double) has, at every further kill, 10 % chance to have two enemy fighters scrambled at him from the nearest enemy airfield (a `campaign_intercept` role: `EngageGroup` on his group); his side is told, once per life.

## Done when

Lua tests: CAP count from the opposition level, strike target choice for each role, cap, no airfield no sortie, Hunter threshold and chance (random injected), once per life.
Python tests: loadout resolution, validation of unknown type and loadout.
In game: an enemy CAP shows up over the front; a CAS flight attacks the target zone.

## As built

The aircraft are declared under `dynamic.air.<side>`, like every live-play setting, with one shipped default per side (made for `MODERN`), not one per era; `air.cap_per_players` (3) sets how many players one CAP answers.
The Hunter is in `dynamic.hunter`.
Every sortie takes off from an airfield, hot on free stands or from the runway (David, 2026-11-15, after the first in-game check: they spawned in the air).
