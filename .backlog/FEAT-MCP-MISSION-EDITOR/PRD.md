# Lot FEAT-MCP-MISSION-EDITOR — MCP server for LLM-assisted mission editing (v1: groups/units)

Status: 🔄 in-progress (waves 1-4 done — 15 tickets, in PR #575 draft; waves 5-8 planned — domain oracle → convention-aware add_group → target symmetry → composite feature builders, tickets 16-28)

Branch: `feature/mcp-mission-editor` → PR → `develop-v6`

## Context

First concrete phase of **NL-MISSION-GEN** (`ROADMAP.md` §4): a natural-language mission
generator, decided to run as a Claude plugin for the mission maker's own AI tooling. Design
reached via a `grill-with-docs` session (see [ADR 0014](../../docs/adr/0014-mission-editor-mcp-editor-parity-layer.md)
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
| FEAT-MCP-MISSION-EDITOR-005 | **End-to-end scenario + doc**: integration test driving `describe_mission` → `add_group` (two ground sections with a patrol route) against a real test `.miz`; a `doc/developer/` page describing the v1 action catalog and the editor-parity/VMCT-action split. | `test/python/`, `doc/developer/` | test+docs | ✅ |

### Wave 2 — zones + script triggers

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| FEAT-MCP-MISSION-EDITOR-006 | **Write action `add_trigger_zone`**: insert a named **circular** trigger zone (`name`, `position`, `radius`, optional `hidden`/`color`) into `mission.triggers.zones` with a fresh `zoneId`, through the 002 backup helper. Handles the list-or-id-keyed-dict shape. Unblocks the full combat-zone scenario (the trigger zone `group_validation` requires + `add_group` units inside it). No dedup. TDD incl. fresh-zoneId safety. | `veaf_mission_mcp/`, `test/python/` | feat | ✅ |
| FEAT-MCP-MISSION-EDITOR-007 | **Write action `add_startup_script_trigger`**: add a "mission start" trigger that either runs **inline Lua** (`DO SCRIPT`) or loads a **`.lua` file** (`DO SCRIPT FILE`) — the file either **static** (embedded into the `.miz` as an `l10n/DEFAULT` resource + `mapResource` entry) or **dynamic** (a disk path loaded at runtime). Generalizes the existing `inject_dcs_bridge_trigger` + static/dynamic loading ([ADR 0004](../../docs/adr/0004-dynamic-script-loading.md)) as a reusable MCP action, for outfitting a **vanilla or CTLD** mission with scripting without the DCS editor. Through the 002 backup helper. TDD on trig/trigrules shape + resource embedding. | `veaf_mission_mcp/`, `mission_tools/` or `mission_builder/`, `test/python/` | feat | ✅ |
| FEAT-MCP-MISSION-EDITOR-008 | **Doc update**: extend `doc/developer/mission-editing-mcp.md` (FR/EN) with the wave-2 actions (`add_trigger_zone`, `add_startup_script_trigger`); CHANGELOG entries; version bump. | `doc/developer/`, `CHANGELOG.md`, `pyproject.toml` | docs | ✅ |

### Wave 3 — editing embedded Lua files (config/scripts, no rebuild)

Third action family: edit the **text** of the Lua files embedded in the `.miz`
(`l10n/DEFAULT/**/*.lua`), neither the raw `mission.lua` tables (editor-parity) nor the
`mission.yaml` pipeline (VMCT action). Brick: `mission_tools.rewrite_miz_members` copies the
archive verbatim and swaps only the named members (no Lua-table re-serialization).

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| FEAT-MCP-MISSION-EDITOR-009 | **Brick + generic action**: `rewrite_miz_members`/`list_members`/`read_member` in `miz_tools.py`, and `replace_in_mission_files` (text or regex search-replace) **restricted to `l10n/DEFAULT/**/*.lua`** (never `mission`/`options`/binaries), backed up first. TDD incl. verbatim-preservation of untouched members. | `mission_tools/miz_tools.py`, `veaf_mission_mcp/`, `test/python/` | feat | ✅ |
| FEAT-MCP-MISSION-EDITOR-010 | **VMCT config edits** on `l10n/DEFAULT/veaf-config.lua`: `set_log_level` (`veaf.ForcedLogLevel`), `set_module_enabled` (`veaf.setConfig(<MOD>,"enable",<bool>)`), `set_security_disabled` (`veaf.SecurityDisabled`), `set_veaf_config` (`veaf.config.<key>`). Each **replaces the line if present, else inserts** it near the top (before module init). Backed up first. TDD. | `veaf_mission_mcp/`, `test/python/` | feat | ✅ |
| FEAT-MCP-MISSION-EDITOR-011 | **Doc update**: extend `mission-editing-mcp.md` (FR/EN) with the wave-3 actions + the third action family; CONTEXT.md glossary entry; CHANGELOG; version bump. | `doc/developer/`, `CONTEXT.md`, `CHANGELOG.md`, `pyproject.toml` | docs | ✅ |

### Wave 4 — VMCT actions on the source `mission.yaml`

The **fourth** (and first genuinely *VMCT*) action family: edit the declarative **design-time
source** `mission.yaml` — the file the build consumes to *generate* the `.miz` — instead of
patching a built artifact. This closes the gap flagged in the original _Out of Scope_: the LLM
can now drive the same declarative pipeline a human uses (`convert-v5`/`veaf-build`), not only
the editor-parity `.miz` surgery.

**Design decision — comment-preserving edits.** `mission.yaml` is a heavily-commented file that
Mission Makers edit by hand, and the shipped default (`src/defaults/mission-folder/mission.yaml`)
is kept in lockstep with generated output. The rest of the codebase loads it with PyYAML
`yaml.safe_load`, which **discards all comments and formatting** on a round-trip — unacceptable
for a source file. These actions therefore use **`ruamel.yaml` round-trip mode** (new dependency)
so comments, key order and layout survive; a scalar-only edit still stays surgical. This mirrors
the wave-3 precedent (`edit_veaf_config` preserves the file, editing only the relevant line) and
respects the CLAUDE.md _defaults-lockstep_ rule. Backed up first, like every write action.

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| FEAT-MCP-MISSION-EDITOR-012 | **Brick — comment-preserving `mission.yaml` editor**: `mission_tools/mission_yaml_editor.py` with `load_yaml`/`save_yaml` on `ruamel.yaml` round-trip mode + a `backup_before_write`-style backup for the `.yaml`. Adds the `ruamel.yaml` dependency. TDD proving comments, key order and formatting survive a load→save round-trip, and that a scalar edit changes only its own line. | `pyproject.toml`, `mission_tools/mission_yaml_editor.py`, `test/python/` | feat | ✅ |
| FEAT-MCP-MISSION-EDITOR-013 | **MCP actions on `mission.yaml`**: `describe_mission_config` (read — list the `modules:` block and each module's enabled/config state) and `set_mission_module` (write — enable/disable a module scalar **or** set its extended config mapping, e.g. a `COMBATZONE`/`CTLD` block, preserving comments). Registered in the catalog next to the wave-3 `set_*` actions. No dedup. TDD on scalar toggle + extended-mapping insert + unknown-module handling. | `veaf_mission_mcp/`, `test/python/` | feat | ✅ |
| FEAT-MCP-MISSION-EDITOR-014 | **Doc update**: extend `mission-editing-mcp.md` (FR/EN) with wave-4 + the fourth (VMCT) action family; CONTEXT.md glossary (`_VMCT action_` now has a concrete implementation); CHANGELOG; version bump. Amend this PRD's _Out of Scope_ (VMCT actions no longer excluded). | `doc/developer/`, `CONTEXT.md`, `CHANGELOG.md`, `pyproject.toml` | docs | ✅ |
| FEAT-MCP-MISSION-EDITOR-015 | **Mission-maker action catalogue** (user-facing): `doc/mission-maker/AI_ASSISTANT_CATALOG.md` (FR/EN) listing every action in plain language, grouped by theme, ordered by estimated frequency, with a complete index + frequency legend and the recipe-vs-built-mission distinction. A **living doc** — future action-adding lots must extend it. Added to the `mkdocs.yml` nav; cross-linked from the developer doc. | `doc/mission-maker/`, `mkdocs.yml`, `doc/developer/`, `CHANGELOG.md` | docs | ✅ |

## Roadmap — waves 5-8 (planned)

Endgame: an LLM builds VEAF combat features **end-to-end, in one pass**, across both worlds
(the `.miz` and the source `mission.yaml`). Three pillars were identified with David: the LLM
already has **hands** (write actions) and **eyes** (`describe_*`); it lacks a **domain brain**.
The waves below add that brain, make group creation convention-aware, restore target symmetry,
and finally ship composite feature builders. Delivery vehicle: a **Claude plugin** = MCP server
(hands/eyes) + skill (brain).

### Wave 5 — Domain knowledge oracle (the "brain") 🧠

Expose all the DCS + VEAF knowledge the LLM needs to author correctly, **hybrid**: structured
facts via MCP read actions generated from the *canonical sources* (no duplication/drift) + a
concise Claude skill for the "how to reason" part.

| # | Ticket | Type | Status |
|---|--------|------|--------|
| FEAT-MCP-MISSION-EDITOR-016 | **Introspection actions**: `list_unit_types` (from `veafUnits`/DCS data, filterable by category/coalition/era), `list_shortcuts` (veafShortcuts aliases, e.g. `-armor`, `-sa2`), `describe_naming_conventions` (the 8 reserved patterns + when each applies), `describe_module` (required/optional keys + semantics, sourced from `lua_config_generator`/`MISSION_YAML_REFERENCE`). | feat | ⬜ |
| FEAT-MCP-MISSION-EDITOR-017 | **Authoring skill** (Claude plugin): a `veaf-mission-authoring` skill teaching the reasoning — naming rules, combat-zone-vs-QRA group models, when to use `#command`/aliases, Late Activation — pointing at the wave-16 actions as the source of truth. | docs | ⬜ |
| FEAT-MCP-MISSION-EDITOR-018 | **Doc + catalogue**: developer doc + mission-maker catalogue updated with the oracle actions. | docs | ⬜ |

### Wave 6 — Convention-aware `add_group` (point 2)

Group creation driven by the oracle: the LLM names groups correctly **itself** (the user gives
intent, not names).

| # | Ticket | Type | Status |
|---|--------|------|--------|
| FEAT-MCP-MISSION-EDITOR-019 | **Naming intents**: `add_group` accepts `for_combat_zone: <zone>` (auto zone-name prefix), `late_activation` (QRA groups), `as_spawn_template` (`veafSpawn-` prefix), and supports `#command="-<alias> …"` fake-unit groups. Generates convention-correct names. | feat | ⬜ |
| FEAT-MCP-MISSION-EDITOR-020 | **Validation & warnings**: `validate_group_name` action + warnings surfaced in `add_group`'s return (reserved-pattern collision, combat-zone capture trap, etc.) for the calling LLM to relay to the user. | feat | ⬜ |
| FEAT-MCP-MISSION-EDITOR-021 | **Doc + catalogue** update. | docs | ⬜ |

### Wave 7 — Target symmetry (point 1)

Every dual-target setting works on **both** the source `mission.yaml` and the built
`veaf-config.lua`.

| # | Ticket | Type | Status |
|---|--------|------|--------|
| FEAT-MCP-MISSION-EDITOR-022 | **Source-side config edits**: `global_log_level`, the `security:` block (incl. password hashes — not covered built-side), per-module `logLevel`, on `mission.yaml`. Unify via a `target: "source" \| "built"` parameter on the config actions. | feat | ⬜ |
| FEAT-MCP-MISSION-EDITOR-023 | **Doc + catalogue** update (parity noted, `target` param documented). | docs | ⬜ |

### Wave 8 — Composite feature builders, one pass, both worlds (point 3 — the goal)

The MCP becomes **mission-folder-aware** (extract `.miz` → `src/mission/`, edit both worlds,
build back) and ships high-level builders. CAS is **excluded** — it is a pure runtime on-demand
mission, not authored into the file.

| # | Ticket | Type | Status |
|---|--------|------|--------|
| FEAT-MCP-MISSION-EDITOR-024 | **Folder-awareness**: operate on a mission folder; extract/build round-trip helper (reuse `mission_promoter`/`extract`/`build`). | feat | ⬜ |
| FEAT-MCP-MISSION-EDITOR-025 | **`create_combat_zone`**: trigger zone + groups placed inside (geometry-based, coalition-agnostic) + `COMBATZONE` yaml block — one call. | feat | ⬜ |
| FEAT-MCP-MISSION-EDITOR-026 | **`create_qra`**: trigger zone + Late-Activation interceptor groups (coalition-significant, named to match) + `QRA` definition — one call. | feat | ⬜ |
| FEAT-MCP-MISSION-EDITOR-027 | **`create_cap_mission`**: `OnDemand-<name>` Late-Activation templates + `combat_missions` yaml block. | feat | ⬜ |
| FEAT-MCP-MISSION-EDITOR-028 | **Doc + catalogue** update (composite section, the recipe-vs-built + one-pass model). | docs | ⬜ |

## Out of Scope

- Non-circular (quad/polygon) trigger zones — wave 2 covers circular zones only.
- A generic SI/ALORS trigger editor (arbitrary DCS conditions/actions) — wave 2's trigger action is scoped to script-loading / Lua-execution startup triggers only, per David's stated need.
- ~~Any VMCT action (e.g. writing a `modules.COMBATZONE` entry in `mission.yaml`)~~ — **now in scope** (wave 4). What stays out: a *full* schema-aware editor for every module's config (wave 4 ships a generic module-toggle + config-mapping setter, not per-module validators).
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
