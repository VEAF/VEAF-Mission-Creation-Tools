# 11 — Zone kinds: factories and depots

Status: 🔄 in-progress

PRD row "Zone kinds" (David, 2026-11-16); analysis notes 01 §1, §5 and 07 §27–§29.

## What

Today every zone is an airfield or a point, held by a garrison, and `kind: logistics` is the only kind.
The V1.5 adds two kinds a mission maker writes on a zone of `campaign.yaml`:

| kind | how it plays |
|---|---|
| (none) on an airfield | **airfield**, as today: captured, its slots follow |
| (none) on a point | **outpost**, as today: a garrison |
| `factory` | a few buildings (statics) plus the zone's garrison; produces resources while its buildings stand (ticket 12); its buildings can be destroyed — by strikes or sappers (ticket 15) — and the zone is captured like any other, a captured factory producing for its new owner |
| `depot` | a garrisoned zone that speeds the supply network and keeps a store of it (ticket 13) |
| `logistics` | unchanged: the episodic campaign's reserve between missions |

Naval bases are later (PRD): ships need an AI of their own.
Airfield and outpost stay implicit — the zone's location already says which — rather than a value to write and keep consistent with it.

## Factory buildings

- Drawn once, at the first start, like a garrison, and recorded in the zone's entry (`structures`: type, position, heading, alive), so they survive the save.
- `dynamic.factory.buildings` (3) buildings among `dynamic.factory.types` (`Workshop A`, `Tech combine`, `Tech hangar A`: DCS statics every map has, each with its `shape_name` in `veafDcsSpawner.SHAPE_NAMES`), in a cluster 60 m apart on open ground inside the zone.
- Always in the world, asleep zone or not: a static costs no AI.
- A building destroyed is recorded at its `S_EVENT_DEAD` and respawned as a wreck (`dead = true`) after a restart.
- A captured factory's standing buildings are respawned under its new owner; a zone turned neutral keeps them as they stand.
- A supply delivery (crate, troops, helicopter) to a factory whose garrison is whole rebuilds one building; the supply network does not (it carries what factories make).
- The F10 label of a factory adds its standing buildings, `2/3`.

## Done when

Python: `kind: factory` and `kind: depot` are accepted, anything else still refused.
Lua tests: buildings drawn, recorded, spawned with their shape; a building's death recorded; a capture respawns the standing ones under the new owner; a delivery rebuilds one; the label counts them; the save keeps them.
