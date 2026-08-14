# 01 — Adding a group assigns its country to its side

Status: ⬜ ready
Type: fix
Files: the group writer shared by `add_group` and the composites under
`src/python/veaf-tools/veaf_mission_mcp/`, `veaf_libs/blank_mission.py` (its comment), tests

## The fix

Wherever a group's country is created or found in `coalition.<side>.country`, add that country's **id**
to `coalitions.<side>` if it is absent. Idempotent — two groups from the same country must not list it
twice.

Both tables in one operation, because they describe the same fact from two angles and DCS needs both.

## Careful

- `coalitions.<side>` is a **list of ids** in a real mission (measured: `blue: [21, 11, 8, …]`), while
  the blank mission ships `{}`. An empty Lua table serialises identically either way, so the writer has
  to cope with both shapes — the quirk `mission_table.indexed` exists for.
- Do **not** invent a default distribution. Measured across this repo's missions, blue holds 5 to 30
  countries and red 3 to 12: there is no canonical set, and inventing one would put countries on a side
  their author never chose.
- The composites (`create_combat_zone`, `create_qra`, `create_cap_mission`) should go through the same
  writer — check that they do rather than assuming, and cover one of them.

## Also

`blank_mission.py:10` claims this already happens. Once it does, the comment becomes true — keep it,
but make it name what actually performs the work, so the next reader can verify instead of trusting.

## TDD

- Failing first: `add_group` on a blank mission, then assert the country id is in `coalitions.<side>`.
- Idempotence: two groups, same country, one entry.
- A second country on the same side appends rather than replaces.
- One composite covered end to end.

## Acceptance criteria

- [ ] `coalitions` populated by every path that creates a group; idempotent.
- [ ] Both the dict and the list shape handled.
- [ ] Full Python gate green.
