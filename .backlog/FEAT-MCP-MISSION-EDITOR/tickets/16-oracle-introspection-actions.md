# FEAT-MCP-MISSION-EDITOR-016 — Domain-oracle introspection actions

Status: ⬜ ready
Type: feat
Files: `src/python/veaf-tools/veaf_mission_mcp/oracle.py`, `veaf_mission_mcp/actions.py`, `test/python/`

## What to build

The structured half of the wave-5 "brain": read-only MCP actions that surface the DCS + VEAF
knowledge the LLM needs to author correctly, **read from the canonical sources** (never
duplicated, so they cannot drift):

- **`list_unit_types`** — DCS unit types, filterable by category / coalition / era, from the
  generated `veaf_libs/data/dcs-*.yaml` (`update-dcs-data`) and `veafUnits` data.
- **`list_shortcuts`** — the veafShortcuts alias vocabulary (`-armor`, `-sa2`, …) an LLM uses in
  `#command`/spawn strings.
- **`describe_naming_conventions`** — the reserved / "magic" naming patterns and when each
  applies (see the list below), so the LLM names groups safely.
- **`describe_module`** — a module's required/optional `mission.yaml` keys + semantics, sourced
  from `veaf_libs/lua_config_generator` and `MISSION_YAML_REFERENCE`.

### Reserved naming conventions the oracle must report

1. Combat-zone membership — group name **starts with the trigger-zone name** (+ inside it) → captured & despawned.
2. `veafSpawn-` prefix → spawnable-aircraft template.
3. `OnDemand-<name>` → CAP-mission template.
4. `VEAF-placeholder-` → build-injected placeholder.
5. `#veafInterpreter["<cmd>"]` in a unit name → unit destroyed + command run at start.
6. Combat-zone unit markers `#command= / #spawngroup= / #spawnradius= / #spawncount= / #spawnchance= / #spawndelay=`.
7. QRA deploy entries starting with `[` or `-` → treated as a command, not a group name.
8. Fixed runtime names `Red CAS Group` / `Blue CAS Group`.

## Acceptance criteria

- [ ] Each action reads from the canonical source module/data — no hardcoded duplicate of the
      DCS/VEAF lists (assert against the same source the build uses).
- [ ] `describe_naming_conventions` returns all 8 conventions with rule + consuming module.
- [ ] `describe_module` returns the required keys for at least `COMBATZONE` and `QRA`.
- [ ] All four registered as read-only `ActionSpec`s; `run_action` dispatches them.
- [ ] TDD; ruff + mypy clean. Coverage gate bumped per the ratchet policy.
- [ ] Mission-maker catalogue updated (living-doc rule).

## Blocked by

None (foundation for waves 6 & 8).
