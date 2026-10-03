# 04 — AI sorties derived from the graph

Status: ⬜ ready

Foothold declares each sortie by hand (`GroupCommander:new({name='Kobuleti-supply-Senaki', …})`, hundreds
per map). Here a side's decision loop derives them from the connections, at a configurable cadence:

| situation along a connection | sortie |
|---|---|
| own zone → **neutral** zone | supply (helicopter if the origin is an airfield/FARP, else convoy) — captures on arrival |
| own zone → own **damaged** zone | supply — restores one lost group on arrival |
| own zone → **enemy** zone | attack: ground convoy, or CAS helicopter |
| own airfield zone | CAP over the frontline zones it connects to (reuse `veafAirWaves` / the CAP role of `veafAircraftSpawn`, no new air AI) |

- Sortie groups are drawn from the VEAF database by era, like garrisons.
- **Caps**: simultaneous sorties per side, and ground convoys separately (the suspected expensive case).
- A sortie launches from a dormant zone without materializing it.
- Both sides use the same loop; blue's can be turned off (setting) for a players-only blue.

## Done when

Tests cover the decision table, the caps, and that a destroyed sortie never captures. One in-game reading
(DCS-SESSION-TODO) that a supply helicopter lands and captures and a convoy reaches its target.
