# 04 — Alias-first: skill directive + oracle categories

Status: ⬜ ready

## Goal

Make the assistant prefer a VEAF alias over hand-placed literal units whenever an alias covers the
need, and make aliases discoverable by category.

## Details

### Skill (`plugin/skills/veaf-mission-authoring/SKILL.md`)

- Add a **general** alias-first principle (not limited to combat zones): when a `list_shortcuts`
  alias covers the need, prefer it — whether a `#command` (zone content) or `#veafInterpreter`
  (permanent asset) — over literal DCS units.
- Give the `#veafInterpreter` section the same preference wording (currently neutral).
- Fix the armor example so it leads with the alias, literal units only as the fallback.
- State the fallback criterion: literal units when no alias fits (precise type/placement needed).

### Oracle (`src/python/veaf-tools/veaf_mission_mcp/oracle.py`)

- Add a structured `category` field to `list_shortcuts` command entries (SAM / AAA / infantry /
  armor / artillery / naval / transport / …), derived from the alias/description, so the assistant
  can enumerate "all SAM aliases" without substring guessing.

## Tests

- `list_shortcuts` commands carry a `category` for the known families (e.g. `-samLR` → SAM,
  `-aaa` → AAA, `-infantry` → infantry).
- Uncategorized aliases get a stable fallback (e.g. `other`), not a crash.
