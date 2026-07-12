# Lot FEAT-MCP-MISSION-EDITOR — MCP server for LLM-assisted mission editing (v1: groups/units)

Status: ⬜ ready

Branch: `feature/mcp-mission-editor` → PR → `develop-v6`

## Context

First concrete phase of **NL-MISSION-GEN** (`ROADMAP.md` §4): a natural-language mission
generator, decided to run as a Claude plugin for the mission maker's own AI tooling. Design
reached via a `grill-with-docs` session (see [ADR 0013](../../docs/adr/0013-mission-editor-mcp-editor-parity-layer.md)
and the new `CONTEXT.md` § "LLM-assisted mission editing").

Goal: an LLM assists a Mission Maker editing their `.miz` directly — and, eventually,
generates a mission end-to-end from a detailed prompt. Two exposed action families:

- **Editor-parity actions** (this lot): mutate the mission's raw source `.miz` the same way
  a human would by hand in the DCS Mission Editor — bypass `mission.yaml` entirely.
- **VMCT actions** (existing, unchanged): the declarative `mission.yaml` → workers pipeline.

The low-level plumbing already exists and is reused, not rebuilt: `luadata` (lossless
Lua↔Python round-trip serializer, `src/python/veaf-tools/luadata/`), `read_miz`/`write_miz`
and the `DcsMission` dataclass (`mission_tools/miz_tools.py`), and two working precedents
for structural mutation in `mission_builder_worker.py` — `inject_dcs_bridge_trigger`
(trigger insertion) and `ensure_coalitions_populated`/`_find_or_add_country`/`_max_ids`
(group insertion with fresh id allocation). This lot generalizes the group-insertion path
into a small, reusable, publicly-callable primitive, and wraps it behind a new MCP server.

Read-side reuses the existing `veaf-tools export` JSON contract (`mission_exporter.py`,
lot `FEAT-EXPORT-BFR-PARSER`) instead of writing a new parser — the LLM needs this to see
current mission state (existing groups/zones) before acting, the same way a human checks
the Mission Editor's outliner before adding something.

## Goal

Ship a first, small MCP server (`veaf-mission-mcp`, Python, lives in this repo) exposing:

1. A `capabilities`/`list_catalog`/`describe_action`/`run_action` surface (same UX shape as
   the existing `dcs-bridge` MCP, for cross-tool consistency).
2. One read action wrapping `export`, so the calling LLM can inspect the current mission
   state (groups, zones, coalitions) before mutating anything.
3. One write action, `add_group`: insert a ground/vehicle group (units, a route/waypoints,
   coalition + country) into the mission's raw `mission.lua`, in place on the source `.miz`,
   preceded by a timestamped backup.

This lays down the **order of battle** first (per David's priority call) — triggers, zones,
and VMCT-action wiring (e.g. registering a `modules.COMBATZONE` entry) are explicitly out of
scope, left to a follow-up wave.

## User Stories

1. As a Mission Maker collaborating with an LLM, I want it to add a ground group with a
   patrol route to my mission's `.miz` directly, so I don't have to place it by hand in the
   Mission Editor.
2. As the calling LLM, I want to list the groups/zones already in the mission before adding
   anything, so I don't blindly duplicate what's already there.
3. As a Mission Maker, I want every mutating action backed up first, so a bad LLM edit is a
   one-command revert away, independent of my own git discipline.

## Tickets

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| FEAT-MCP-MISSION-EDITOR-001 | **MCP server skeleton**: new `veaf_mission_mcp` package + Poetry entry point, `capabilities`/`list_catalog`/`describe_action`/`run_action` scaffolding with an initially-empty catalog. Adds the MCP SDK dependency. | `pyproject.toml`, `src/python/veaf-tools/veaf_mission_mcp/`, `test/python/` | feat | ✅ |
| FEAT-MCP-MISSION-EDITOR-002 | **Backup-before-write**: shared helper that copies the target `.miz` to a timestamped sibling file before any mutating action runs; every write action in this server goes through it. TDD on the copy + naming scheme. | `mission_tools/miz_tools.py` (or a new sibling module), `test/python/` | feat | ✅ |
| FEAT-MCP-MISSION-EDITOR-003 | **Read action `describe_mission`**: wraps `mission_exporter.py` (no new parsing) to list groups/zones/coalitions from the mission's current `.miz`, exposed as an MCP action. | `veaf_mission_mcp/`, `test/python/` | feat | ✅ |
| FEAT-MCP-MISSION-EDITOR-004 | **Write action `add_group`**: generalize the group-insertion logic already in `ensure_coalitions_populated`/`_find_or_add_country`/`_max_ids` (`mission_builder_worker.py`, `coalition_placeholder.py`) into a reusable public function — units list, route/waypoints (patrol support), coalition + country, fresh `groupId`/`unitId` allocation — exposed as an MCP action going through the 002 backup helper. No deduplication: two calls make two groups. TDD incl. patrol route + id-collision safety. | `mission_builder/coalition_placeholder.py` (or extracted), `veaf_mission_mcp/`, `test/python/` | feat | ✅ |
| FEAT-MCP-MISSION-EDITOR-005 | **End-to-end scenario + doc**: integration test driving `describe_mission` → `add_group` (two ground sections with a patrol route) against a real test `.miz`; a `doc/developer/` page describing the v1 action catalog and the editor-parity/VMCT-action split. | `test/python/`, `doc/developer/` | test+docs | ⬜ |

## Out of Scope

- Zone and trigger/trigrule editor-parity actions (next wave).
- Any VMCT action (e.g. writing a `modules.COMBATZONE` entry in `mission.yaml`) — stays the
  existing CLI/config path, untouched by this lot.
- Unit-type catalog or curation: picking concrete DCS unit types stays the calling LLM's
  job (`dcs-reference` agent, `veafUnits` data) — this server only accepts an already-decided
  `{type, count}` list.
- Composite actions (e.g. a single `create_combat_zone` call) — primitives only for v1.
- Distribution via the `bfr-claude-plugins` marketplace (packaging concern, later).

## Further Notes

- Updates `ROADMAP.md` §4 (`NL-MISSION-GEN` now has a started first phase) and `CONTEXT.md`
  (new "LLM-assisted mission editing" section: _Editor-parity action_ / _VMCT action_).
- `master` has not yet had a complete v6 release cut (still v5.103.3; latest is
  `published-v6.9.0` off `develop-v6`) — David confirmed proceeding anyway under normal
  gitflow (branch off `develop-v6`, dev release picks it up), not waiting for the master cut.
