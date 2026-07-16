# FEAT-MCP-MISSION-EDITOR-016 — Domain-oracle introspection actions

Status: ✅ done
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

- [x] Each action reads from the canonical source module/data — no hardcoded duplicate of the
      DCS/VEAF lists (`dcsUnits.yaml`, `veaf-units.yaml`, `lua_module_scanner.get_modules`).
- [x] `describe_naming_conventions` returns all 8 conventions with rule + consuming module.
- [x] `describe_module` locates a module (known/doc-page/enabled) — a **locator**, not a schema
      validator (per-module keys live in the module's doc page; see the ticket rationale).
- [x] All four registered as read-only `ActionSpec`s; `run_action` dispatches them.
- [x] TDD (11 tests); ruff + mypy clean.
- [ ] Coverage gate bump — **deferred**: full-suite coverage isn't measurable on David's PC
      (`veaf_build` editable install unavailable offline); bump against CI's measured %.
- [x] Mission-maker catalogue updated (living-doc rule) — new "Domain knowledge" theme, FR/EN.

## Blocked by

None (foundation for waves 6 & 8).
