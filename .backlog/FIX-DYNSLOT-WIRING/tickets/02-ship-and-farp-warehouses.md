# 02 — Wire the ship and FARP warehouses

Status: ✅ done

## Problem

`apply_warehouses` iterates `warehouses.airports` and nothing else. DCS keeps ships and FARPs in a
second section, `warehouses.warehouses`, and dynamic slots work there — the worker's own docstring
says so.

Measured on the fully built `test-import.miz`: `airports` ends with 832 links and **0** pointing at
a missing group; `warehouses` keeps its 69 links, **all 69** pointing at a group that does not
exist. Nine of its 41 entries carry stock. Nothing in the pipeline stocks them, links them, or
cleans the dead links a previous build left behind.

For a carrier-based airframe — the F-14 being exactly that — this is a complete explanation on its
own, independent of every other defect in this lot.

## Open question, to settle before writing

`warehouses.yaml` only has an `airports:` key today, and an airport is designated by name (resolved
through the theatre) or by numeric id. A ship or a FARP has neither: the section is keyed by the
**unit id** of the carrying object, which is not something a mission maker reads off the Mission
Editor.

To look at before proposing: what the Mission Editor exposes as a handle, and whether the carrying
group/unit **name** can be resolved to that id from the mission table (it can be, for groups the
mission owns — the unit id is in `units[].unitId`). If it can, the config key should be the name.

Proposal to confirm with David once measured:

```yaml
blue:
  defaults: { fuel: unlimited, weapons: unlimited }
  ships:            # optional; absent -> every ship/FARP of this coalition
    CVN-75: {}
```

Falling back to the numeric unit id, as `airports:` already allows, for anything that cannot be
named.

## Work

- Extend `apply_warehouses` to the second section, reusing `_apply_to_airport` where the shape is
  identical (`dynamicSpawn`, `allowHotStart`, fuel/munitions, stock, `linkDynTempl`).
- Resolve a ship/FARP by carrying-unit name, else by id.
- Do **not** apply the parking filter there: `parkable_kinds` is keyed by airfield id and means
  nothing for a ship. A carrier parks planes and helicopters; a FARP parks helicopters. Establish
  which by measuring rather than assuming, and write down what was measured.
- Clean a `linkDynTempl` that points at nothing, the same way the airport path already ends up doing
  by overwriting.

## Tests

- A mission with a carrier and a FARP: both get `dynamicSpawn`, stock and a link that resolves.
- A coalition not declared leaves its ships untouched.
- A pre-existing dead link on a ship is gone after the step.
- Naming a ship by its unit name and by its numeric id reach the same entry.
