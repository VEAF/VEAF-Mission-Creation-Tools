# 01 — `create_combat_zone` appends its zones below the trailing comments

Status: ⬜ ready
Type: fix
Files: the `create_combat_zone` implementation under `src/python/veaf-tools/veaf_mission_mcp/`, tests

## What happens

Calling `create_combat_zone` on a `mission.yaml` that already holds a `combat_zones:` list appends
the new entry **after the trailing commented-out block**, not next to the list. Measured on
2026-08-18 while building `verify-mission-c`: the existing list ended at line 154, and the two new
entries landed at line 208 — below `# ── Community scripts (off by default …) ─────`, immediately
before `STTS: false`.

## Why it matters even though it parses

`yaml.safe_load` returns all three zones under `combat_zones`, because comments do not interrupt a
sequence. So nothing breaks — **today**. What breaks is the person: the entries read as if they
belonged to the community-scripts section, and the shipped `mission.yaml` is a reference file that
mission makers edit by hand. An entry sitting under the wrong heading is one a maker moves or
deletes.

It also breaks the file's own contract with `FIX-BUILD-YAML-TRUNCATION`: content near the tail of
the file is exactly what a `--dev-mode` build rewrites.

## Done when

- A zone appended to an existing list is written after the list's **last real item**, before any
  trailing comment block
- A zone created when no `modules.COMBATZONE.combat_zones:` key exists yet still works (the current
  behaviour for that case is fine — do not regress it)
- A test starts from a `mission.yaml` whose `combat_zones:` list is followed by commented-out lines,
  and asserts the insertion point by **line order**, not just by parsing the result — a parse-only
  assertion passes today and would not have caught this
