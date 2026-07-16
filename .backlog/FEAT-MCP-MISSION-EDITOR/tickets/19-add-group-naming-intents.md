# FEAT-MCP-MISSION-EDITOR-019 — `add_group` naming intents

Status: ⬜ ready
Type: feat
Files: `src/python/veaf-tools/veaf_mission_mcp/add_group.py`, `veaf_mission_mcp/actions.py`, `test/python/`

## What to build

Let the calling LLM express *intent* and have `add_group` produce a **convention-correct name**
itself, instead of the user hand-naming groups. New optional parameters, layered on the existing
`add_group`:

- `for_combat_zone: <zone_name>` — prefix the group name with the combat-zone trigger-zone name
  (the membership rule: name must start with the zone name), e.g. zone `CZ-North` →
  `CZ-North-<name>`.
- `late_activation: bool` — mark the group late-activation (required for QRA interceptors and
  CAP/on-demand templates).
- `as_spawn_template: bool` — prefix with `veafSpawn-` (registers it as a spawnable-aircraft
  template).

These compose with the existing `name`/`units`/`route`/`patrol`. The oracle
(`describe_naming_conventions`, wave 5) is the source of truth for the rules encoded here.

## Acceptance criteria

- [ ] `for_combat_zone` yields a name starting with the exact zone name (idempotent if the
      caller already prefixed it — no double prefix).
- [ ] `late_activation` sets the DCS late-activation flag on the inserted group.
- [ ] `as_spawn_template` yields a `veafSpawn-` prefixed name.
- [ ] Intents compose; the base `add_group` behaviour is unchanged when none are given.
- [ ] TDD; ruff + mypy clean. Coverage gate per the ratchet.
- [ ] Mission-maker catalogue updated (living-doc rule).

## Blocked by

None (builds on the shipped wave-5 oracle + existing `add_group`).
