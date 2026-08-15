# FIX-CONVERT-SPAWNABLES-FLAT-FORMAT

Status: ✅ done

## Problem

`convert-v5` generates an **empty** `spawnables.yaml` (and `dynamic-slot-templates.yaml`)
for missions whose `src/spawnableAircrafts/settings.lua` uses the **flat** v5 layout —
spawnable aircraft are silently dropped. Reported by Tripack (mission converted in
`d:\dev\_VEAF\tmp\test-tripack`).

## Root cause

`convert_aircraft_groups` (`mission_builder/v5_pipeline_converters.py`) only parses the
**nested** export layout:

```
settings.categories.<cat>.coalitions.<coa>.countries.<cty>.groups[<name>]
```

But two real v5 export layouts exist in the wild (two `veafSpawnableAircraftsEditor`
generations) — verified across 77 real missions under `d:\dev\_VEAF`: **41 nested**,
**32 flat**, 4 empty:

```
flat:  settings.<collection>.{ coalition, country, category, groups[<idx>].name }
```

For a flat file, `raw.get("categories")` is `None` → the loop never runs → empty output.
The converter's own test fixture used the nested layout, so the gap was never caught.

## Fix

Detect the layout (presence of the `categories` wrapper) and handle **both**; the v6
output is identical. Neither format is removed — both are real and must convert.

- Nested: existing logic (groups keyed by name).
- Flat: iterate the collections, read scalar `category`/`coalition`/`country`, walk
  `groups` (numeric index), take the name from `group["name"]`, classify, route.

## Out of scope

- The `_spawn` marker database template (`spawn-groups.yaml`) — unrelated, correctly
  shipped as a commented default.

---

## 01 — Support the flat spawnableAircrafts layout

Status: ✅ done

### Tasks

- [x] `convert_aircraft_groups`: detect the layout (`categories` wrapper) and add a flat
      parser; share the routing/classification with the nested path.
- [x] Tests: keep the nested fixture; add a flat fixture (Tripack-style, numeric group
      index + name inside) asserting non-empty spawnables, helicopter routing, and
      dynamic-template split.
- [x] CHANGELOG `[Unreleased]`; PATCH bump (6.7.2 → 6.7.3); `poetry install`.

### Definition of Done

- `poetry run pytest` green, coverage held; ruff/format/mypy clean.
- A flat-layout `settings.lua` converts its `veafSpawn-` groups into `spawnables.yaml`
  (verified against `d:\dev\_VEAF\tmp\test-tripack`).
