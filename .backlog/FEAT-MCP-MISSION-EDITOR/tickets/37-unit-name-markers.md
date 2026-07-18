# FEAT-MCP-MISSION-EDITOR-037 — Optional explicit unit name (enables `#command`/`#spawn*`)

Status: ✅ done
Type: feat
Files: `src/python/veaf-tools/veaf_mission_mcp/add_group.py`, `veaf_mission_mcp/actions.py`, `test/python/veaf_mission_mcp/`

## Problem

The combat-zone idiom is a fake-unit group whose **unit name** carries `#command="-<alias> ..."`
(also `#spawngroup=`/`#spawnradius=`/`#spawncount=`/`#spawnchance=`/`#spawndelay=`), parsed from the
unit name by `veafCombatZone.lua`. The oracle + skill teach it, but `add_group`/`create_combat_zone`
auto-name every unit and expose only `{type, count}` — so the marker was unbuildable via the MCP.

## What to build

- `_build_units`: if a unit spec has a `name`, use it (verbatim for `count == 1`; suffixed
  `"<name> #NN"` for `count > 1` to keep DCS unit-name uniqueness — the substring marker still
  parses); otherwise keep the current auto-name.
- Add an optional `name` to the `add_group` units item schema, documented as the place to carry a
  combat-zone marker (e.g. `#command="-armor ..."`). Composites inherit it (they pass `units`
  through to `insert_group_into_content` → `_build_units`, no change needed).

## Acceptance criteria

- [ ] A unit spec with `name` produces a unit of that exact name (count 1); count>1 stays unique.
- [ ] No `name` → current auto-name unchanged (regression).
- [ ] A `create_combat_zone` group with a `#command="-armor ..."` fake unit round-trips: the unit
      name is present in the built folder/`.miz`.
- [ ] ruff + mypy clean (full-tree).
