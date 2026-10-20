# 03 — The reference data an AI needs before a mission folder exists

Status: ✅ done

The export lists what the AI read from the exe's own files instead of an action (PRD, finding 3).
For each, first check whether an action already answers it and the guide or the prompt fails to point to it; add an action only where none does:

- DCS country ids by name;
- parking capacity per airfield of a theatre;
- the ATC frequencies of a theatre's airfields, with no mission;
- whether a type can be placed as a static;
- the shipped dynamic-slot templates (type, frequency);
- lat/lon ↔ x/y for a theatre with no mission folder (`resolve_coordinates`, `geocode` and `terrain_elevation` took a `mission_path`);
- the `combat_zones` keys of `mission.yaml`.

Done when: each item is answered by an action an AI finds from the guide, tested; the prompts' phase 1 (read-only, before the scaffold) can be done without a folder.

## Done (2026-10-20)

| Item | Answered by |
|---|---|
| DCS country ids by name | new `list_countries` (`name_contains`) |
| Parking capacity per airfield | `list_airfields` `details: true` → `parking.planes` / `parking.helicopters` |
| ATC frequencies with no mission | `list_airfields` `details: true` → `atc` (`uhf`, `vhf`, `fm`, `tacan`) |
| A type as a static | already possible: `add_group` `category: static` takes any type of the unit database; its schema now says so |
| Shipped dynamic-slot templates | `read_mission_file` without `mission_path` reads the shipped scaffold |
| lat/lon ↔ x/y with no mission | `resolve_coordinates` and `geocode` take `theatre` (`list_airfields`, `terrain_elevation` already did) |
| `combat_zones` keys | `create_combat_zone`'s `combat_zone` schema lists them; a test checks each is read by the generator |

The objective prompt's phase 1 named the data files (`veaf_libs/data/parking/<theatre>.json`, `freq_alias.py`) and said `geocode` took no theatre: rewritten in both languages to the actions.
