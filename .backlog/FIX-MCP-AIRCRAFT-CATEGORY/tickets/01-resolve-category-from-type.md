# 01 — Resolve the aircraft category from the type

Status: ✅ done 2026-08-16 — both actions, 9 tests, verified on a rebuilt mission
Type: fix
Files: `src/python/veaf-tools/veaf_libs/dcs_units_data.py` (new),
`src/python/veaf-tools/mission_tools/group_insertion.py`,
`src/python/veaf-tools/veaf_mission_mcp/add_air_group.py`,
`src/python/veaf-tools/veaf_mission_mcp/player_slot.py`, their three test modules

## The change

`air_category_for_type_verbose(unit_type) -> (category, warning)` in `group_insertion.py`, beside
`GROUP_CATEGORIES` where the category vocabulary already lives, plus a thin
`air_category_for_type()` for callers that surface the warning some other way. Both actions call it
instead of passing a literal, and both return the resolved `category` so the caller can see what was
decided.

The lookup itself is `veaf_libs/dcs_units_data.py`, modelled on the existing `dcs_airdromes.py`: a
cached `{type: category}` table read from the bundled `dcsUnits.yaml`.

## Why a warning rather than a refusal for an unknown type

The database covers what DCS ships, not what a mission maker has installed — `Hercules`, a
third-party C-130, is absent. Refusing would break a legitimate call for a type the maker knows
exists. Guessing silently would rebuild the exact defect this ticket fixes. So: place it under
`plane`, and say so, naming the type.

## Tests

- The helper: helicopters, planes, an unknown type's fallback, and that the fallback is *reported*.
- Each action: a helicopter lands under `helicopter` **and is absent from `plane`** (a one-sided
  assertion would have passed before the fix), a plane still lands under `plane`, an unclassifiable
  type warns.

## Verified beyond the tests

The CTLD test mission was rebuilt through the real pipeline and its mission table read back:
`CTLD-Huey` (UH-1H) and `CTLD-Chinook` (CH-47Fbl1) under `blue/USA/helicopter`, `skill=Client`,
`parking=12`/`13`, waypoint `TakeOffParking` / `From Parking Area`.
