# Lot FEAT-MCP-MISSION-EDITOR — MCP server for LLM-assisted mission editing (v1: groups/units)

Status: ✅ done — umbrella **PR #575 merged into `develop`** (David closed it after VM testing). Waves 1-12 delivered: the MCP spans create→edit→validate→build→play. Distribution as a Claude plugin is done (`FEAT-MCP-PLUGIN`, self-hosted in this repo), and the follow-up real-usage lots landed on the integration branch before the merge (`FEAT-MCP-ADD-GROUP-FOLDER`, `FEAT-MCP-ORACLE-COMMANDS`, `FEAT-MCP-AIRBASES-WAREHOUSES`, plus the stdout/updater/build-stdin fixes). Projection is a pure-Python copy of `projection.lua` (MIT, `bfr-claude-plugins`); MGRS dropped. More-theatre data remains a general backlog item, not a blocker.

Branch: `feature/mcp-mission-editor` → PR → `develop`

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

**Knowledge sources (reuse, never reinvent)** — the oracle draws on data VEAF already generates
and publishes, so it can't drift from reality:

- **Generated DCS data** (`update-dcs-data`): unit types, countries, airfield frequencies —
  shipped as `veaf_libs/data/dcs-*.yaml`, published on the VEAF GitHub.
- **VEAF unit aliases / shortcuts** (`veafUnits`, veafShortcuts) — the `-armor`/`-sa2`… vocabulary.
- **Vendored third-party artifacts** (`vendored.yaml`, `check-vendored` drift-watch): pinned
  community scripts (CTLD/CSAR/…) and their provenance.
- **Upstream datamining repos** referenced as provenance for the DCS data above.

The oracle actions read these existing lists rather than duplicating them.

| # | Ticket | Type | Status |
|---|--------|------|--------|
| FEAT-MCP-MISSION-EDITOR-016 | **Introspection actions**: `list_unit_types` (from generated `dcsUnits.yaml`, filterable), `list_shortcuts` (veaf-units.yaml aliases + composite groups), `describe_naming_conventions` (the 8 reserved patterns), `describe_module` (**locator** over `lua_module_scanner` → doc page + enabled state, not a schema validator). | feat | ✅ |
| FEAT-MCP-MISSION-EDITOR-017 | **Authoring skill** (Claude plugin): `plugin/skills/veaf-mission-authoring/SKILL.md` teaching the reasoning — naming rules, combat-zone-vs-QRA group models, `#command`/aliases, Late Activation, intent-not-names — pointing at the 016 actions as the source of truth. Versioned in veaf-tools, bundled by `bfr-claude-plugins`. | docs | ✅ |
| FEAT-MCP-MISSION-EDITOR-018 | **Doc + catalogue**: developer doc (FR/EN) + CONTEXT glossary + mission-maker catalogue + CHANGELOG + bump 6.9.5. | docs | ✅ |

### Wave 6 — Convention-aware `add_group` (point 2)

Group creation driven by the oracle: the LLM names groups correctly **itself** (the user gives
intent, not names).

| # | Ticket | Type | Status |
|---|--------|------|--------|
| FEAT-MCP-MISSION-EDITOR-019 | **Naming intents**: `add_group` accepts `for_combat_zone: <zone>` (auto zone-name prefix), `late_activation` (QRA groups), `as_spawn_template` (`veafSpawn-` prefix). Generates convention-correct names via `group_naming.resolve_group_name`. | feat | ✅ |
| FEAT-MCP-MISSION-EDITOR-020 | **Validation & warnings**: `validate_group_name` action + warnings surfaced in `add_group`'s return (reserved-pattern collision, combat-zone capture trap) for the calling LLM to relay to the user. | feat | ✅ |
| FEAT-MCP-MISSION-EDITOR-021 | **Doc + catalogue** update (dev doc FR/EN, catalogue, skill, CHANGELOG, bump 6.9.6). | docs | ✅ |

### Wave 7 — Target symmetry (point 1)

Every dual-target setting works on **both** the source `mission.yaml` and the built
`veaf-config.lua`.

| # | Ticket | Type | Status |
|---|--------|------|--------|
| FEAT-MCP-MISSION-EDITOR-022 | **Source-side config parity**: `set_mission_log_level` (`global_log_level`), `set_mission_security` (`security:` block incl. password hashes — not covered built-side), `set_mission_setting` (`settings.<key>` → `veaf.config.<key>`) on `mission.yaml`. Shipped as **separate source-side actions** (consistent with wave-4 `set_mission_module`), not a `target` param. | feat | ✅ |
| FEAT-MCP-MISSION-EDITOR-023 | **Doc + catalogue** update (source-side setters + recipe/built parity noted). | docs | ✅ |

### Wave 8 — Composite feature builders, one pass, both worlds (point 3 — the goal)

The MCP becomes **mission-folder-aware** (extract `.miz` → `src/mission/`, edit both worlds,
build back) and ships high-level builders. CAS is **excluded** — it is a pure runtime on-demand
mission, not authored into the file.

| # | Ticket | Type | Status |
|---|--------|------|--------|
| FEAT-MCP-MISSION-EDITOR-024 | **Folder-awareness**: operate on a mission folder; extract/build round-trip helper (reuse `mission_promoter`/`extract`/`build`). | feat | ✅ |
| FEAT-MCP-MISSION-EDITOR-025 | **`create_combat_zone`**: trigger zone + groups placed inside (geometry-based, coalition-agnostic) + `COMBATZONE` yaml block — one call. | feat | ✅ |
| FEAT-MCP-MISSION-EDITOR-026 | **`create_qra`**: trigger zone + Late-Activation interceptor groups (coalition-significant, named to match) + `QRA` definition — one call. | feat | ✅ |
| FEAT-MCP-MISSION-EDITOR-027 | **`create_cap_mission`**: `OnDemand-<name>` Late-Activation templates + `combat_missions` yaml block. | feat | ✅ |
| FEAT-MCP-MISSION-EDITOR-028 | **Doc + catalogue** update (composite section, the recipe-vs-built + one-pass model). | docs | ✅ |

### Wave 9 — Scaffolding a fresh mission folder from GitHub 🏗️

The **upstream** piece: everything before wave 8 assumes a mission folder already exists. Wave 9
lets the LLM create one from an **empty folder**, driving the real VEAF bootstrap the way a human
would — download the updater, run it (fetches + installs the VEAF tools into the folder), then
`veaf-tools prepare` to lay down the default scaffold. **Decision (with David)**: a single MCP
action **driving the real binaries** (not re-implementing the updater/prepare logic in-process),
faithful to a user's own first-run experience. The release exposes fixed-name Windows assets
(`veaf-tools-updater.exe`, `veaf-tools.exe`) and per-OS Unix assets, so the updater is fetched by
its stable release-download URL (no GitHub API, no rate limit); the updater itself handles the
`published.zip` fetch and its optional token.

The `custom` template is **not** supported here (it opens an interactive TUI picker with no TTY
under a subprocess); the action accepts `minimal`/`standard`/`full`. The template *question* is
the calling LLM's job (surfaced in the skill), passed as a required action parameter.

| # | Ticket | Type | Status |
|---|--------|------|--------|
| FEAT-MCP-MISSION-EDITOR-029 | **`scaffold_mission` action**: on an empty target folder — (1) resolve the updater asset for the current OS and download it from the stable release URL, (2) run it (`cwd=folder`, optional `--token`/`--tag`) and verify `veaf-tools[.exe]` + `published/` appeared, (3) run `veaf-tools[.exe] prepare --template <minimal\|standard\|full> --force`. Refuses a non-empty folder. Small cross-OS updater-asset-name helper in `platform_assets.py`. TDD mocks the download + `subprocess.run` (sequence, args, cwd, non-empty-folder guard, invalid template, updater/prepare failure surfaced). | feat | ⬜ |
| FEAT-MCP-MISSION-EDITOR-030 | **Doc + catalogue + skill**: developer doc (FR/EN) "Scaffolding (wave 9)" section, `AI_ASSISTANT_CATALOG` entry (step 0 of a from-scratch mission), `veaf-mission-authoring` skill step 0 + the template question, CHANGELOG, bump 6.9.9. | docs | ⬜ |

### Wave 10 — Map reading + human coordinate input (lat/long, MGRS) 🗺️

Every placement action so far takes **DCS local coordinates** (`x`/`y`, metres in the theatre's
own projection). A Mission Maker rarely thinks in x/y — they think lat/long or MGRS off a map.
Wave 10 lets a maker (via the LLM) place things by human coordinates and read the map for
bearings.

**Coordinate projection — resolved by reuse.** The DCS `coord.*` conversions
(`LLtoLO`/`LOtoLL`/`LLtoMGRS`/`MGRStoLL`) live in the **in-game Lua runtime** and are unavailable
design-time; the repo has no Python projection. Rather than derive one, we **port an existing,
tested implementation**: `bfr-claude-plugins/plugins/dcs-mission-tools/tools/src/lib/projection.lua`
(MIT) — a Transverse Mercator WGS84 forward/inverse plus per-theatre tables (`lon0`/`x0`/`y0`) for
**caucasus, syria, persiangulf, marianaislands**, with 5 reference test cases we reuse as Python
fixtures. This is the recommended "knowledge as data" path (ADR 0007), now with zero in-house
derivation risk and no heavy dependency. We **copy the code into Python** outright (short
attribution header, MIT-compatible with our Apache-2.0) — no shared upstream, no drift-tracking.
MGRS is not in the source and is a minor, deferrable extra (theatre-independent) — done at its
simplest if/when needed, never a blocker.

| # | Ticket | Type | Status |
|---|--------|------|--------|
| FEAT-MCP-MISSION-EDITOR-031 | **Coordinate projection foundation (port) + ADR 0015**: copy `projection.lua` (MIT, `bfr-claude-plugins`) into pure-Python `veaf_libs/coordinates.py` — TM WGS84 forward/inverse + the 4-theatre tables; reuse its 5 reference cases as tests. Short attribution header. ADR 0015 records the copy + provenance. MGRS deferred (not needed now). TDD against the reference pairs. | feat | ✅ |
| FEAT-MCP-MISSION-EDITOR-032 | **`describe_map` + `resolve_coordinates` actions**: `describe_map` (read — theatre name, bullseye(s), existing trigger zones/groups as reference points, so the LLM can orient without DCS running); `resolve_coordinates` (convert freely between `{x,y}`, `{lat,lon}`, `{mgrs}` for the mission's theatre, using 031). | feat | ✅ |
| FEAT-MCP-MISSION-EDITOR-033 | **Human-coordinate input on placement actions**: `add_group`, `add_trigger_zone` and the wave-8 composites accept a `position` given as `{lat,lon}` or `{mgrs}` in addition to `{x,y}`, converting via 031 before insertion. Backward compatible (x/y unchanged). TDD on each accepted form + theatre-mismatch handling. | feat | 🚫 |
| FEAT-MCP-MISSION-EDITOR-034 | **Doc + catalogue + skill**: developer doc (FR/EN) map/coordinates section, `AI_ASSISTANT_CATALOG` entries, skill guidance (prefer human coords, ask which system), CONTEXT glossary (theatre projection), CHANGELOG, bump. | docs | ✅ |

### Wave 11 — close the loop: build + validate 🏁

The MCP can create, orient and edit a mission folder, but nothing produces the playable `.miz` —
the maker still runs `veaf-tools build` by hand. Wave 11 makes the server **self-sufficient A→Z**:
scaffold → theatre blank → composites/placement → **validate → build → playable `.miz`**, without
leaving the assistant.

**Design decision.** `validate_mission` calls the existing `veaf_libs.mission_validator.validate_mission_folder`
**in-process** (clean, testable, no binary needed). `build_mission` **drives the real
`veaf-tools build`** via subprocess (`cwd=folder`) — the build orchestration lives in the CLI
command (many workers + config resolution), so re-invoking it is faithful and avoids duplication;
`scaffold_mission` has already installed `veaf-tools[.exe]` in the folder (fall back to PATH).

| # | Ticket | Type | Status |
|---|--------|------|--------|
| FEAT-MCP-MISSION-EDITOR-035 | **`validate_mission` + `build_mission` actions**: `validate_mission` (in-process `validate_mission_folder` → `{ok, errors, warnings}`); `build_mission` (subprocess `veaf-tools build`, `cwd=folder`, resolve the folder's binary else PATH → `{ok, message}`, non-zero exit surfaced). Registered in the catalog. TDD: validate on a real folder fixture; build with `subprocess.run` mocked (command, cwd, failure path). | feat | ✅ |
| FEAT-MCP-MISSION-EDITOR-036 | **Doc + catalogue + skill**: developer doc (FR/EN) "Build & validate (wave 11)" section, `AI_ASSISTANT_CATALOG` entries (the create→edit→build→play loop), skill (validate before build; build to get the playable `.miz`), CHANGELOG, bump. | docs | ✅ |

### Wave 12 — unit-name markers (`#command`, `#spawn*`) 🏷️

**Gap found in testing (David).** The oracle and skill both teach the combat-zone idiom of a
**fake-unit group whose unit name carries `#command="-<alias> ..."`** (parsed by
`veafCombatZone.lua`: `#command=`/`#spawngroup=`/`#spawnradius=`/`#spawncount=`/`#spawnchance=`/
`#spawndelay=` live in the **unit name**). But `add_group`/`create_combat_zone` build units from
`{type, count}` and **auto-name** every unit — there was no way to emit a unit name carrying a
marker, so the recommended idiom was unbuildable through the MCP. That is why the LLM didn't use
`#command` when creating a combat zone: the tool gave it no path to.

Fix: let a unit carry an optional explicit `name`, honoured by `_build_units` (else the auto-name),
exposed in the `add_group` schema; the composites already pass units through, so they inherit it.

| # | Ticket | Type | Status |
|---|--------|------|--------|
| FEAT-MCP-MISSION-EDITOR-037 | **Optional unit name**: `_build_units` honours a unit's `name` (verbatim for count 1; suffixed for count>1 to keep DCS unit-name uniqueness), else the current auto-name. Add `name` to the `add_group` units schema (composites inherit it via pass-through). Enables the `#command="-armor ..."` fake-unit combat-zone idiom the skill already recommends. TDD: explicit name honoured, count>1 uniqueness, auto-name unchanged, `#command` round-trips through the `.miz`/folder. | feat | ✅ |
| FEAT-MCP-MISSION-EDITOR-038 | **Doc + catalogue + skill**: developer doc (FR/EN) + catalogue note that a unit can carry a name (the `#command`/`#spawn*` combat-zone markers), with a worked `create_combat_zone` example using a `#command` fake-unit; reinforce it in the authoring skill; CHANGELOG; bump. | docs | ✅ |

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
  `published-v6.9.0` off `develop`) — David confirmed proceeding anyway under normal
  gitflow (branch off `develop`, dev release picks it up), not waiting for the master cut.

---

## FEAT-MCP-MISSION-EDITOR-001 — MCP server skeleton

Status: ✅ done
Type: feat
Files: `pyproject.toml`, `src/python/veaf-tools/veaf_mission_mcp/`, `test/python/`

### What to build

A new `veaf_mission_mcp` package exposing an MCP server with the same action-discovery
shape as the existing `dcs-bridge` MCP tool (for cross-tool consistency, no protocol reuse
required):

- `capabilities` — static info (server name/version).
- `list_catalog` — enumerate registered actions (initially empty; populated by later
  tickets in this lot).
- `describe_action(name)` — parameters/schema for one action.
- `run_action(name, params)` — dispatch to the registered handler.

Add the MCP SDK dependency to `pyproject.toml` under `[tool.poetry.dependencies]`, and a
new `[tool.poetry.scripts]` entry (e.g. `veaf-mission-mcp = "veaf_mission_mcp.server:main"`).

### Acceptance criteria

- [ ] `poetry run veaf-mission-mcp` starts the server.
- [ ] `list_catalog` returns an empty list before any action is registered.
- [ ] `describe_action`/`run_action` on an unknown name return a clear error, not a crash.
- [ ] TDD; ruff + mypy clean (new package must not be added to the mypy `ignore_errors`
      exclusion list — see the Quality Ratchet Policy in `CLAUDE.md`).

---

## FEAT-MCP-MISSION-EDITOR-002 — Backup-before-write helper

Status: ✅ done
Type: feat
Files: `mission_tools/miz_tools.py` (or a new sibling module), `test/python/`

### What to build

A shared helper, called by every mutating MCP action before it writes, that copies the
target `.miz` to a timestamped sibling (e.g. `mission.miz` → `mission.20260712-143012.miz`,
same directory) before `write_miz` overwrites it. Pure safety net — no retention/cleanup
policy, no configuration; git remains the actual long-term undo.

### Acceptance criteria

- [x] Backup file is byte-identical to the pre-write `.miz`.
- [x] Timestamp format is sortable and collision-safe within the same second: a `-2`, `-3`, ...
      suffix disambiguates rather than raising — an LLM driving several editor-parity actions
      in a row (FEAT-MCP-MISSION-EDITOR-004) can call this twice within the same second, and
      every call must still produce a backup.
- [x] Backup happens even if the subsequent write fails (helper runs first, unconditionally).
- [x] TDD; ruff + mypy clean.

---

## FEAT-MCP-MISSION-EDITOR-003 — Read action `describe_mission`

Status: ✅ done
Type: feat
Files: `src/python/veaf-tools/veaf_mission_mcp/`, `test/python/`

### What to build

An MCP action `describe_mission(miz_path)` that wraps the existing `export`/
`mission_exporter.py` JSON contract (no new parsing — `FEAT-EXPORT-BFR-PARSER` already
solved this) to return, at minimum, groups (name, coalition, country, category) and
trigger-zone names/positions from the mission's current `.miz`. Gives the calling LLM
situational awareness before it runs a write action — mirroring how a human checks the
Mission Editor's outliner before adding something.

### Acceptance criteria

- [ ] Reuses `mission_exporter.py` output; does not re-implement Lua/JSON parsing.
- [ ] Returns groups and trigger zones at minimum (coalitions/countries as available from
      the export contract).
- [ ] Clear error on a `.miz` that doesn't exist or isn't a valid mission archive.
- [ ] TDD against a real test `.miz`; ruff + mypy clean.

### Blocked by

FEAT-MCP-MISSION-EDITOR-001.

---

## FEAT-MCP-MISSION-EDITOR-004 — Write action `add_group`

Status: ✅ done
Type: feat
Files: `mission_builder/coalition_placeholder.py` (or extracted), `src/python/veaf-tools/veaf_mission_mcp/`, `test/python/`

### What to build

Generalize the group-insertion logic already proven in `ensure_coalitions_populated` /
`_find_or_add_country` / `_max_ids` (`mission_builder/coalition_placeholder.py`,
`mission_builder_worker.py`) into a small, reusable public function —
`add_group(mission: DcsMission, coalition, country, group_definition) -> group_id` — and
expose it as the MCP action `add_group`, accepting:

- coalition + country
- a unit list (`{type, count}` per `FEAT-MCP-MISSION-EDITOR` scope decision — the MCP does
  not curate unit types, the caller already decided them)
- a route (waypoints — must support a patrol pattern, the motivating use case)
- position (or the units' individual positions)

Allocates fresh `groupId`/`unitId` (reusing `_max_ids`), deep-copies/builds the group
structure, appends it under the right `country["vehicle"]["group"]` (or the relevant
category), and calls `write_miz` through the `FEAT-MCP-MISSION-EDITOR-002` backup helper.
No deduplication: calling this twice with identical parameters creates two distinct groups
— the tool mirrors the Mission Editor, it doesn't second-guess the caller.

### Acceptance criteria

- [x] Adds a ground group with units + a patrol route to a real test `.miz`, and DCS/the
      Mission Editor would open the result without complaint (validated at minimum via
      `luadata` round-trip + `mission_content` shape checks; a manual DCS open is a bonus,
      not a gate).
- [x] Fresh `groupId`/`unitId` never collide with existing ones, including on a mission
      already containing gaps (sparse ids).
- [x] Backup helper (002) runs before the write, every time.
- [x] Calling the action twice with the same input produces two groups, not one (explicit
      non-dedup test).
- [x] TDD incl. patrol-route shape; ruff + mypy clean.

### Note

Ticket 002's backup collision handling was changed from *raise* to *disambiguate* (`-2`,
`-3`, ... suffix): calling `add_group` twice in a row can land in the same second, and every
call must still produce a backup — see the updated `miz_backup.backup_before_write`
docstring and `.backlog/FEAT-MCP-MISSION-EDITOR/tickets/02-backup-before-write.md`.

Also generalized `coalition_placeholder.py`'s `_max_ids`/`_find_or_add_country`/
`_coerce_country_list` into public `mission_tools.group_insertion` helpers (single source
of truth for id bookkeeping), refactoring `coalition_placeholder.py` to use them —
existing `test_coalition_placeholder.py` suite still green.

### Blocked by

FEAT-MCP-MISSION-EDITOR-001, FEAT-MCP-MISSION-EDITOR-002.

---

## FEAT-MCP-MISSION-EDITOR-005 — End-to-end scenario + doc

Status: ✅ done
Type: test+docs
Files: `test/python/`, `doc/developer/`

### What to build

- An integration test driving the full v1 catalog against a real test `.miz`:
  `describe_mission` → `add_group` (two ground sections with a patrol route) →
  `describe_mission` again to confirm the new groups are visible and the backup file
  exists.
- A `doc/developer/` page (`.en` mirror) documenting the v1 action catalog
  (`describe_mission`, `add_group`), the editor-parity/VMCT-action split (link
  [ADR 0014](../../docs/adr/0014-mission-editor-mcp-editor-parity-layer.md) and the
  `CONTEXT.md` glossary entries), and how to run the server locally.

### Acceptance criteria

- [x] Integration test passes against a real (not mocked) test `.miz`.
- [x] Doc page merged, FR + EN, linked from the developer doc index.

### Blocked by

FEAT-MCP-MISSION-EDITOR-003, FEAT-MCP-MISSION-EDITOR-004.

---

## FEAT-MCP-MISSION-EDITOR-006 — Write action `add_trigger_zone`

Status: ✅ done
Type: feat
Files: `veaf_mission_mcp/`, `test/python/`

### What to build

An MCP action `add_trigger_zone` inserting a **circular** trigger zone into
`mission.triggers.zones`:

- Parameters: `miz_path`, `name`, `position` (`{x, y}`), `radius`, optional `hidden`
  (default false) and `color` (`[r, g, b, a]`, default a neutral translucent).
- Zone shape: `{name, x, y, radius, zoneId, type: 0, hidden, color, properties: {}}`
  (matches the DCS circular-zone shape).
- Fresh `zoneId` past the highest existing one. Handle `triggers.zones` being either a
  list or an id-keyed dict.
- Goes through the `FEAT-MCP-MISSION-EDITOR-002` backup helper. No dedup.

Unblocks the full combat-zone scenario: this trigger zone is what `group_validation`
requires for a `modules.COMBATZONE` entry, and `add_group` (v1) drops the units inside it.

### Acceptance criteria

- [ ] Adds a circular zone visible via `describe_mission` afterwards.
- [ ] Fresh `zoneId` never collides with existing ones (incl. sparse ids).
- [ ] Backup runs before the write.
- [ ] Two calls create two zones (explicit non-dedup test).
- [ ] TDD; ruff + mypy clean.

---

## FEAT-MCP-MISSION-EDITOR-007 — Write action `add_startup_script_trigger`

Status: ✅ done
Type: feat
Files: `veaf_mission_mcp/`, `mission_tools/` or `mission_builder/`, `test/python/`

### What to build

An MCP action adding a **"mission start"** trigger that runs a script — for outfitting a
**vanilla or CTLD** mission with scripting without fighting the DCS editor's Triggers tab.
Modes:

- **Inline Lua** (`DO SCRIPT`): a `lua` string executed at mission start.
- **Script file** (`DO SCRIPT FILE`): load a `.lua` file, either
  - **static** — embed the file into the `.miz` as an `l10n/DEFAULT/<name>.lua` resource, add
    its `mapResource` entry, and reference it from the action; or
  - **dynamic** — a disk path loaded at runtime (no embedding).

Generalizes the existing `inject_dcs_bridge_trigger` (which injects a trigger loading
`dcs-bridge.lua`) and the VEAF static/dynamic loading mechanism
([ADR 0004](../../docs/adr/0004-dynamic-script-loading.md)) into a reusable MCP action.
Goes through the `FEAT-MCP-MISSION-EDITOR-002` backup helper.

### Acceptance criteria

- [ ] Inline-Lua mode: a `triggerStart` trigger with a `DO SCRIPT` action carrying the Lua.
- [ ] Static-file mode: the `.lua` is embedded (`l10n/DEFAULT` + `mapResource`) and referenced
      by a `DO SCRIPT FILE` action.
- [ ] Dynamic-file mode: a runtime disk-path load, no embedding.
- [ ] trig/trigrules indices stay consistent (mirror `inject_dcs_bridge_trigger`'s shifting).
- [ ] Backup runs before the write. No dedup.
- [ ] TDD on trig/trigrules shape + resource embedding; ruff + mypy clean.

### Blocked by

FEAT-MCP-MISSION-EDITOR-002.

---

## FEAT-MCP-MISSION-EDITOR-008 — Wave-2 doc + changelog

Status: ✅ done
Type: docs
Files: `doc/developer/`, `CHANGELOG.md`, `pyproject.toml`

### What to build

- Extend `doc/developer/mission-editing-mcp.md` (+ `.en` mirror) with the wave-2 actions:
  `add_trigger_zone` and `add_startup_script_trigger` (inline / static-file / dynamic-file),
  including the vanilla/CTLD use case.
- CHANGELOG `[Unreleased]` entries for both actions.
- PATCH version bump in `pyproject.toml` + `poetry install`.

### Acceptance criteria

- [ ] Doc updated FR + EN.
- [ ] CHANGELOG + version bump done.

### Blocked by

FEAT-MCP-MISSION-EDITOR-006, FEAT-MCP-MISSION-EDITOR-007.

---

## FEAT-MCP-MISSION-EDITOR-009 — Brick + generic search-replace

Status: ✅ done
Type: feat
Files: `mission_tools/miz_tools.py`, `veaf_mission_mcp/`, `test/python/`

### What to build

- Brick in `miz_tools.py`: `rewrite_miz_members(miz_path, {arcname: bytes})` (copies the
  archive verbatim, swaps only named members — no Lua-table re-serialization), plus
  `list_members` / `read_member`.
- Action `replace_in_mission_files(search, replace, files="*.lua", regex=False)` — text or
  regex search-replace **restricted to `l10n/DEFAULT/**/*.lua`** (glob matched on the path
  relative to `l10n/DEFAULT/`; only `.lua` members ever eligible). Backed up first; returns
  `{files_changed, total_replacements}`.

### Acceptance criteria

- [x] Only `l10n/DEFAULT/**/*.lua` members are touched — never `mission`/`options`/binaries.
- [x] Untouched members stay byte-identical (no normalization).
- [x] Text and regex (with backrefs) modes; no-match = no change, no backup.
- [x] Invalid regex → clear error. TDD; ruff + mypy clean.

---

## FEAT-MCP-MISSION-EDITOR-010 — VMCT config edits (veaf-config.lua)

Status: ✅ done
Type: feat
Files: `veaf_mission_mcp/edit_veaf_config.py`, `test/python/`

### What to build

Semantic edits of a built mission's `l10n/DEFAULT/veaf-config.lua`, without a rebuild.
Each **replaces** the target line if present, else **inserts** it near the top (before the
modules initialise). Backed up first.

- `set_log_level(level)` → `veaf.ForcedLogLevel = "<level>"` (validated against the 5 levels).
- `set_module_enabled(module_id, enabled)` → `veaf.setConfig("<MOD>", "enable", <bool>)`.
- `set_security_disabled(disabled)` → `veaf.SecurityDisabled = <bool>`.
- `set_veaf_config(key, value)` → `veaf.config.<key> = <lua scalar>` (key must be a bare id).

### Acceptance criteria

- [x] Replace-if-present, insert-if-absent for each action.
- [x] `set_module_enabled` only touches the targeted module's line.
- [x] Scalars rendered as Lua literals (bool/int/float/string).
- [x] Clear error when the mission has no `veaf-config.lua`. TDD; ruff + mypy clean.

### Note

Security **password hashes** (`veafSecurity.password_L9[...]` / `password_MM[...]`) — a
multi-line add/remove case — are **not** covered here; only the `SecurityDisabled` flag is.
Flagged to David at the wave-3 checkpoint for a follow-up if wanted.

### Blocked by

FEAT-MCP-MISSION-EDITOR-009 (the `rewrite_miz_members` brick).

---

## FEAT-MCP-MISSION-EDITOR-011 — Wave-3 doc + glossary + changelog

Status: ✅ done
Type: docs
Files: `doc/developer/`, `CONTEXT.md`, `CHANGELOG.md`, `pyproject.toml`

### What to build

- Extend `doc/developer/mission-editing-mcp.md` (+ `.en`) with the wave-3 actions
  (`replace_in_mission_files`, `set_log_level`, `set_module_enabled`,
  `set_security_disabled`, `set_veaf_config`) and the third action family.
- Add a `CONTEXT.md` glossary entry for the embedded-Lua-edit family.
- CHANGELOG entries; PATCH version bump.

### Acceptance criteria

- [x] Doc FR + EN updated.
- [x] CONTEXT.md glossary entry added.
- [x] CHANGELOG + version bump done.

---

## FEAT-MCP-MISSION-EDITOR-012 — Comment-preserving `mission.yaml` editor (brick)

Status: ✅ done
Type: feat
Files: `pyproject.toml`, `mission_tools/mission_yaml_editor.py`, `test/python/`

### What to build

The reusable primitive every wave-4 VMCT action goes through: load and save the **source**
`mission.yaml` **without losing comments, key order or formatting**.

The rest of the codebase loads `mission.yaml` with PyYAML `yaml.safe_load`, which discards
all comments on a round-trip. `mission.yaml` is a heavily-commented source file edited by
hand (and the shipped default is kept in lockstep with generated output), so a lossy
round-trip is unacceptable. Use **`ruamel.yaml` in round-trip mode** instead.

- Add the `ruamel.yaml` dependency to `pyproject.toml` (and lock).
- New module `mission_tools/mission_yaml_editor.py`:
  - `load_yaml(path: Path) -> CommentedMap` — round-trip load.
  - `save_yaml(path: Path, data: CommentedMap) -> None` — round-trip dump, backed up first.
  - A `backup_before_write`-style timestamped backup of the `.yaml` (reuse the wave-1
    helper's scheme if it generalizes, else a sibling of it).

### Acceptance criteria

- [x] A `load_yaml` → `save_yaml` round-trip with no mutation leaves the file **byte-stable**
      (comments, blank lines, key order, indentation all preserved).
- [x] Editing a single scalar value changes only that value's rendering, not unrelated lines.
- [x] The `.yaml` is backed up (timestamped sibling) before every save.
- [x] TDD; ruff + mypy clean. Coverage gate bumped per the ratchet policy.

### Note

Per the CLAUDE.md quality ratchet: this adds a new dependency — keep it a **required** dep
(not an optional extra) since the MCP server always needs it. New module ships fully typed;
do not add it to the mypy `ignore_errors` list.

### Blocked by

None (foundation for tickets 13-14).

---

## FEAT-MCP-MISSION-EDITOR-013 — MCP actions on `mission.yaml`

Status: ✅ done
Type: feat
Files: `veaf_mission_mcp/edit_mission_yaml.py`, `veaf_mission_mcp/actions.py`, `test/python/`

### What to build

Two MCP actions editing the declarative **source** `mission.yaml`, both going through the
ticket-012 brick (comment-preserving, backed up first). Registered in the catalog alongside
the wave-3 `set_*` actions.

- **`describe_mission_config`** (read): return the `modules:` block and, per module, its state
  — `mandatory` (bare key), `enabled: bool` (scalar form), or the extended config mapping
  (e.g. a `COMBATZONE`/`CTLD`/`SKYNET` block). Read-only, no backup. Mirrors `describe_mission`
  but for the config source rather than the built `.miz`.
- **`set_mission_module`** (write): given a `module_id` and either
  - a boolean → set/replace the scalar `MODULE: <bool>`, or
  - a mapping → set/replace the module's **extended config block** (e.g.
    `COMBATZONE: { enabled: true, combat_zones: [...] }`),
  preserving surrounding comments. Insert the key if absent, replace if present. No dedup.

### Acceptance criteria

- [x] `describe_mission_config` reports the three module shapes (mandatory / scalar / extended)
      correctly against a representative `mission.yaml`.
- [x] `set_mission_module` scalar toggle flips only the targeted module's value, comments intact.
- [x] `set_mission_module` mapping form writes a well-formed extended block that survives a
      re-load (and would be accepted by the existing `mission_builder` YAML consumer).
- [x] Clear error for a malformed `mission.yaml` path / non-mapping `modules:` block.
- [x] Both actions registered with a JSON-Schema `ActionSpec`; `run_action` dispatches them.
- [x] TDD; ruff + mypy clean. Coverage gate bumped per the ratchet policy.

### Note

Scope is a **generic** module toggle + config-mapping setter — **not** a per-module
schema-aware validator (that stays out of scope). The LLM is responsible for the shape of the
config mapping it passes, the same way it already picks unit types for `add_group`.

### Blocked by

FEAT-MCP-MISSION-EDITOR-012 (the `mission_yaml_editor` brick).

---

## FEAT-MCP-MISSION-EDITOR-014 — Wave-4 documentation

Status: ✅ done
Type: docs
Files: `doc/developer/mission-editing-mcp.md`, `doc/developer/mission-editing-mcp.en.md`, `CONTEXT.md`, `CHANGELOG.md`, `pyproject.toml`

### What to build

- Extend `doc/developer/mission-editing-mcp.md` (FR) and `.en.md` (EN) with the wave-4
  actions (`describe_mission_config`, `set_mission_module`) and the **fourth action family**:
  editing the declarative source `mission.yaml` (design-time), distinct from the three
  existing families (editor-parity `.miz` tables, embedded-Lua text, built-`veaf-config.lua`).
- Update the `CONTEXT.md` glossary: `_VMCT action_` now has a concrete implementation
  (previously only the declarative CLI/config path).
- `CHANGELOG.md` entry under `[Unreleased]`.
- Bump the PATCH version in `pyproject.toml`; `poetry install`.
- Amend this lot's PRD `## Out of Scope` (VMCT actions are no longer excluded — already done
  when the wave was opened; confirm it reads correctly at close).

### Acceptance criteria

- [x] Both language docs describe the two new actions and the four-family model consistently.
- [x] CONTEXT.md `_VMCT action_` entry updated.
- [x] CHANGELOG + version bump landed; markdown-lint clean.

### Blocked by

FEAT-MCP-MISSION-EDITOR-013 (documents the shipped actions).

---

## FEAT-MCP-MISSION-EDITOR-015 — Mission-maker action catalogue (user-facing doc)

Status: ✅ done
Type: docs
Files: `doc/mission-maker/AI_ASSISTANT_CATALOG.md`, `doc/mission-maker/AI_ASSISTANT_CATALOG.en.md`, `mkdocs.yml`, `doc/developer/mission-editing-mcp.md`, `CHANGELOG.md`

### What to build

A **user-facing** (not developer) catalogue of everything a Mission Maker can ask the AI to do
through the MCP, in plain language — distinct from the technical `developer/` doc.

- Grouped **by theme**, ordered by **estimated frequency of use**, with a **complete index** at
  the top and a frequency legend.
- Explains the two editing levels (source `mission.yaml` recipe vs built `.miz`) and the
  backup-before-write safety net, in user terms.
- Example phrases per action ("what you can say to the AI").
- FR base + EN mirror; added to the `mkdocs.yml` nav under *Mission Maker*.
- Cross-linked from the developer doc.

### Acceptance criteria

- [x] Every currently-shipped action (waves 1-4, 11 actions) appears in the index and a themed
      section, tagged with an estimated frequency.
- [x] FR + EN pages, in nav, custom anchors resolve (`attr_list` enabled).
- [x] Framed as a **living doc** — explicitly grows as the MCP gains capabilities.

### Note

Living document: any future lot that adds an MCP action MUST add it to this catalogue (index +
themed section + frequency estimate) as part of its Definition of Done.

---

## FEAT-MCP-MISSION-EDITOR-016 — Domain-oracle introspection actions

Status: ✅ done
Type: feat
Files: `src/python/veaf-tools/veaf_mission_mcp/oracle.py`, `veaf_mission_mcp/actions.py`, `test/python/`

### What to build

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

#### Reserved naming conventions the oracle must report

1. Combat-zone membership — group name **starts with the trigger-zone name** (+ inside it) → captured & despawned.
2. `veafSpawn-` prefix → spawnable-aircraft template.
3. `OnDemand-<name>` → CAP-mission template.
4. `VEAF-placeholder-` → build-injected placeholder.
5. `#veafInterpreter["<cmd>"]` in a unit name → unit destroyed + command run at start.
6. Combat-zone unit markers `#command= / #spawngroup= / #spawnradius= / #spawncount= / #spawnchance= / #spawndelay=`.
7. QRA deploy entries starting with `[` or `-` → treated as a command, not a group name.
8. Fixed runtime names `Red CAS Group` / `Blue CAS Group`.

### Acceptance criteria

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

### Blocked by

None (foundation for waves 6 & 8).

---

## FEAT-MCP-MISSION-EDITOR-017 — `veaf-mission-authoring` Claude skill (the "how to reason")

Status: ✅ done
Type: docs
Files: `plugin/skills/veaf-mission-authoring/SKILL.md`, `plugin/README.md`, `doc/developer/`

### What to build

The prose half of the wave-5 "brain": a Claude skill teaching the LLM **how to reason** when
authoring a VEAF mission — the judgement the structured oracle actions (ticket 016) can't encode:

- Naming rules in practice, and when to reach for `#command`/aliases vs literal units.
- Combat-zone group model (geometry-based, coalition-agnostic, placed active) **vs** QRA group
  model (referenced by exact name, coalition-significant, **Late Activation**).
- When to ask the user vs decide autonomously (the user gives intent, not names).
- Always call the oracle actions (016) as the source of truth for unit types / conventions /
  module schemas — the skill points at them rather than restating volatile data.

### Acceptance criteria

- [x] Skill loads and references the ticket-016 actions as the authoritative data source.
- [x] Covers the combat-zone-vs-QRA distinction and the "intent not names" principle with
      worked examples ("create a CZ with two armor groups", "a QRA with Mirage 2000s").
- [x] No duplication of the volatile DCS/VEAF lists (those stay in the oracle actions).

### Note

Delivery vehicle is the **Claude plugin** (MCP server = hands/eyes + this skill = brain). Placement
decided (David): the skill is **versioned in veaf-tools** under `plugin/skills/`, next to the MCP
server, and bundled/referenced by the separate `bfr-claude-plugins` packaging (out of scope here).

### Blocked by

FEAT-MCP-MISSION-EDITOR-016 (the skill points at the oracle actions).

---

## FEAT-MCP-MISSION-EDITOR-018 — Wave-5 documentation

Status: ✅ done
Type: docs
Files: `doc/developer/mission-editing-mcp.md` (FR/EN), `doc/mission-maker/AI_ASSISTANT_CATALOG.md` (FR/EN), `CONTEXT.md`, `CHANGELOG.md`, `pyproject.toml`

### What to build

- Developer doc (FR/EN): document the oracle introspection actions (016) and the four-source
  knowledge model (generated DCS data / veafUnits+shortcuts / vendored artifacts / datamining
  provenance).
- Mission-maker catalogue (FR/EN): add the read-side "the AI knows DCS + VEAF" actions to the
  index + a themed section (living-doc rule).
- CONTEXT.md glossary entry if a new term is warranted (e.g. "domain oracle").
- CHANGELOG entry; PATCH version bump.

### Acceptance criteria

- [x] Both language docs describe the oracle actions and knowledge sources consistently.
- [x] Catalogue index + section updated; anchors resolve (done in 016, verified here).
- [x] CHANGELOG + version bump (6.9.5) landed; markdown-lint deferred to the CI docs job.

### Blocked by

FEAT-MCP-MISSION-EDITOR-016 / 017 (documents what they ship).

---

## FEAT-MCP-MISSION-EDITOR-019 — `add_group` naming intents

Status: ✅ done
Type: feat
Files: `src/python/veaf-tools/veaf_mission_mcp/add_group.py`, `veaf_mission_mcp/actions.py`, `test/python/`

### What to build

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

### Acceptance criteria

- [x] `for_combat_zone` yields a name starting with the exact zone name (idempotent,
      case-insensitive — no double prefix).
- [x] `late_activation` sets the DCS `lateActivation` flag on the inserted group.
- [x] `as_spawn_template` yields a `veafSpawn-` prefixed name.
- [x] Intents compose; base `add_group` behaviour unchanged when none given (default not late-activation).
- [x] TDD (10 tests); ruff + mypy clean.
- [ ] Coverage gate bump — deferred (full-suite coverage not measurable locally; bump vs CI %).
- [x] Mission-maker catalogue updated (living-doc rule) — "Add a group" section, FR/EN.

### Blocked by

None (builds on the shipped wave-5 oracle + existing `add_group`).

---

## FEAT-MCP-MISSION-EDITOR-020 — Group-name validation & warnings

Status: ✅ done
Type: feat
Files: `src/python/veaf-tools/veaf_mission_mcp/group_naming.py`, `veaf_mission_mcp/add_group.py`, `veaf_mission_mcp/actions.py`, `test/python/`

### What to build

Surface convention collisions so the calling LLM can warn/ask the user (the server itself does
not converse):

- **`validate_group_name`** action — given a proposed name (and optionally the target `.miz`),
  return the reserved-convention matches it triggers: `veafSpawn-`, `OnDemand-`,
  `VEAF-placeholder-`, `#veafInterpreter[...]`, combat-zone unit markers, and — if a `.miz` is
  given — the **combat-zone capture trap** (name starts with an existing combat-zone trigger-zone
  name → would be captured/despawned).
- **Warnings in `add_group`'s return** — `add_group` runs the same check and includes any
  `warnings` in its result (it still performs the write; the LLM relays the warning).

Encodes the same 8 conventions the wave-5 `describe_naming_conventions` reports (shared helper).

### Acceptance criteria

- [x] `validate_group_name` flags each reserved pattern with a clear reason.
- [x] With a `.miz`, it detects the combat-zone prefix-capture trap against real trigger zones
      (and suppresses the caller's intended zone via `expected_combat_zone`).
- [x] `add_group` returns non-empty `warnings` for a colliding name, and still writes.
- [x] A clean name yields no warnings.
- [x] TDD (12 tests); ruff + mypy clean.
- [ ] Coverage gate bump — deferred (not measurable locally; bump vs CI %).
- [x] Mission-maker catalogue updated (FR/EN).

### Note

`resolve_group_name` (from ticket 019) was moved into the new `group_naming.py` alongside
`validate_group_name` for cohesion; `add_group` re-exports it, so nothing downstream broke.

### Blocked by

FEAT-MCP-MISSION-EDITOR-019 (shares the naming helper).

---

## FEAT-MCP-MISSION-EDITOR-021 — Wave-6 documentation

Status: ✅ done
Type: docs
Files: `doc/developer/mission-editing-mcp.md` (FR/EN), `doc/mission-maker/AI_ASSISTANT_CATALOG.md` (FR/EN), `CHANGELOG.md`, `pyproject.toml`

### What to build

- Developer doc (FR/EN): document the `add_group` naming intents (`for_combat_zone`,
  `late_activation`, `as_spawn_template`) and the `validate_group_name` action.
- Mission-maker catalogue (FR/EN): reflect that the AI now names groups itself from intent, and
  add `validate_group_name` to the index + a section.
- Update the `veaf-mission-authoring` skill if the guidance shifts.
- CHANGELOG entry; PATCH version bump.

### Acceptance criteria

- [x] Both language docs describe the intents and validation consistently.
- [x] Catalogue updated (in 019/020); anchors resolve.
- [x] CHANGELOG + version bump (6.9.6) landed. `veaf-mission-authoring` skill updated to point at
      the intents + `validate_group_name`.

### Blocked by

FEAT-MCP-MISSION-EDITOR-019 / 020.

---

## FEAT-MCP-MISSION-EDITOR-022 — Source-side config parity (`mission.yaml`)

Status: ✅ done
Type: feat
Files: `src/python/veaf-tools/veaf_mission_mcp/edit_mission_yaml.py`, `veaf_mission_mcp/actions.py`, `test/python/`

### What to build

Every VEAF config setting that today can only be edited on the **built** `veaf-config.lua`
(wave 3) gets its **source** `mission.yaml` counterpart, so both targets are reachable. Uses the
comment-preserving `mission_yaml_editor` brick, backed up first.

Mapping (confirmed in `veaf_libs/lua_config_generator`):

- **`set_mission_log_level(level)`** → top-level `global_log_level: <level>` (↔ built `set_log_level`).
- **`set_mission_security(disabled, password_hashes?, password_mm_hashes?)`** → the `security:`
  block (↔ built `set_security_disabled` — and covers the password hashes the built side does not).
- **`set_mission_setting(key, value)`** → `settings.<key>` (↔ built `set_veaf_config`, which sets
  `veaf.config.<key>`).

Module enable already has both targets (`set_module_enabled` built, `set_mission_module` source),
so it is not re-done here.

### Design note

Shipped as **separate source-side actions** (naming consistent with the wave-4 `set_mission_module`),
not a `target:` parameter on the built-side actions — the wave-4 split already established the
one-action-per-target pattern, and a param would collide with it. Parity (David's point 1) is about
coverage, achieved either way.

### Acceptance criteria

- [x] Each setter edits the correct `mission.yaml` key/block, comments preserved, backed up first.
- [x] `set_mission_log_level` validates the level against the 5 levels.
- [x] `set_mission_security` sets `disabled` and, when given, the hash lists; leaves other keys intact.
- [x] `set_mission_setting` inserts/updates `settings.<key>` (creates `settings:` if absent).
- [x] All registered as actions; `run_action` dispatches them. TDD (5 tests); ruff + mypy clean.
- [x] Mission-maker catalogue updated (FR/EN) — "Modules & settings" now "Recipe + built".

### Blocked by

None (builds on the wave-4 `mission_yaml_editor` brick).

---

## FEAT-MCP-MISSION-EDITOR-023 — Wave-7 documentation

Status: ✅ done
Type: docs
Files: `doc/developer/mission-editing-mcp.md` (FR/EN), `doc/mission-maker/AI_ASSISTANT_CATALOG.md` (FR/EN), `CHANGELOG.md`, `pyproject.toml`

### What to build

- Developer doc (FR/EN): document the source-side config setters and note the recipe/built
  parity (which setting maps to which `mission.yaml` key vs `veaf-config.lua` line).
- Mission-maker catalogue (FR/EN): the "Modules & settings" theme now has a **recipe** counterpart
  for log level / security / arbitrary setting; update the index + sections.
- CHANGELOG entry; PATCH version bump.

### Acceptance criteria

- [x] Both language docs describe the source-side setters and the parity (recipe/built table).
- [x] Catalogue updated (in 022); anchors resolve.
- [x] CHANGELOG + version bump (6.9.7) landed.

### Blocked by

FEAT-MCP-MISSION-EDITOR-022.

---

## FEAT-MCP-MISSION-EDITOR-024 — Mission-folder awareness (extract/build round-trip)

Status: ✅ done
Type: feat
Files: `src/python/veaf-tools/veaf_mission_mcp/mission_folder.py`, `test/python/`

### What to build

The foundation for the composite builders: let the MCP operate on a **mission folder** (the
editable source: `mission.yaml` + `src/mission/` exploded `.miz`), not only a standalone built
`.miz`. A composite feature lives in **both worlds** (trigger zones/groups in `src/mission/`, the
module config in `mission.yaml`), so a one-pass builder must edit both and then realise it.

- A small `mission_folder` helper that resolves a folder's pieces: the `mission.yaml`, the
  exploded mission under `src/mission/`, and (re)builds a `.miz` from the folder via the existing
  CLI/worker (`veaf-tools build`, `MissionBuilderWorker`, `mission_promoter.promote_mission_to_v6`
  for the extract-back half).
- The wave-1/2 editor-parity primitives (`add_group`, `add_trigger_zone`) currently operate on a
  `.miz` zip; make them reusable against the folder's mission representation (edit `src/mission/`,
  or edit a built `.miz` then extract back — decide during implementation, see below).

### Design decision — settled (David, model 1)

Composites **edit the durable source**: the exploded `src/mission/` (zones/groups) + `mission.yaml`
(config). No build is triggered by the composite — a later `veaf-tools build` produces the `.miz`.
The exploded `mission` file is mutated with the existing pure-Python `luadata` parser via the new
`write_mission_folder` (sibling of the existing `read_mission_folder`) — no zip, no Lua execution.

### Acceptance criteria

- [x] `mission_folder` resolves both sides of a folder: `mission_yaml_path()` and the exploded
      mission (`load_folder_mission`).
- [x] `write_mission_folder` (in `mission_tools.miz_tools`) writes `mission_content` back to the
      loose `mission` file, leaving the rest of the folder intact.
- [x] `save_folder_mission` backs the `mission` file up first, then writes.
- [x] TDD (4 tests); ruff + mypy clean (full-tree, CI-exact). No auto-build (model 1).

### Blocked by

None (reuses `mission_builder`/`mission_extractor`/`mission_promoter`).

---

## FEAT-MCP-MISSION-EDITOR-025 — `create_combat_zone` (one pass, both worlds)

Status: ✅ done
Type: feat
Files: `src/python/veaf-tools/veaf_mission_mcp/composites.py`, `veaf_mission_mcp/actions.py`, `test/python/`

### What to build

A single high-level action that lays down a complete VEAF combat zone across both worlds, by
orchestrating the wave-1..7 primitives on a mission folder (ticket 024):

1. **Trigger zone** (`add_trigger_zone`) — the circular zone `<zone_name>`.
2. **Groups inside it** (`add_group` with `for_combat_zone=<zone_name>`) — placed geometrically
   inside the zone, names prefixed so the zone captures them; coalition-agnostic (VEAF respawns).
   The LLM supplies the `{type,count}` groups (using the wave-5 oracle for types).
3. **`mission.yaml` config** (`set_mission_module`) — a `COMBATZONE` block referencing `zone_name`.

Then (optionally) build. Not deduplicated. Returns a summary of what it created + any
`validate_group_name` warnings.

### Acceptance criteria

- [x] One call produces: the trigger zone, ≥1 correctly-named group inside it, and the
      `modules.COMBATZONE.combat_zones[]` entry — verified by re-reading the folder.
- [x] Group names satisfy the combat-zone membership rule (zone-name prefix, via `resolve_group_name`).
- [x] Appends to existing `combat_zones` (second call = two zones), doesn't clobber.
- [x] TDD (2 tests) against a real mission folder fixture; ruff + mypy clean (full-tree).
- [x] Mission-maker catalogue updated — new "🏗️ Composites" headline theme, FR/EN.

### Note

Extracted content-level cores `insert_trigger_zone` / `insert_group_into_content` (from
`add_trigger_zone` / `add_group`) so the composite reuses them on the folder's exploded mission —
the `.miz` actions now delegate to the same cores (behavior-preserving).

### Blocked by

FEAT-MCP-MISSION-EDITOR-024.

---

## FEAT-MCP-MISSION-EDITOR-026 — `create_qra` (one pass, both worlds)

Status: ✅ done
Type: feat
Files: `src/python/veaf-tools/veaf_mission_mcp/composites.py`, `veaf_mission_mcp/actions.py`, `test/python/`

### What to build

A single action laying down a complete VEAF QRA across both worlds (contrast with the combat
zone: QRA groups are referenced **by exact name**, coalition **matters**, and interceptors are
**Late Activation**):

1. **Trigger zone** (`add_trigger_zone`) — the protected-airspace zone (or accept a `zone_radius`).
2. **Interceptor group(s)** (`add_group` with `late_activation=True`, the definition's coalition,
   coherent names) — the LLM picks the aircraft type (wave-5 oracle).
3. **`mission.yaml` config** (`set_mission_module` on `QRA`) — a `definitions[]` entry with
   `name`, `coalition`, `trigger_zone`, and `simple_groups` listing the interceptor group names
   **verbatim**.

### Acceptance criteria

- [x] One call produces: the trigger zone, the Late-Activation interceptor group(s) on the right
      coalition, and the `modules.QRA.definitions[]` entry referencing the group name(s) verbatim.
- [x] The group name in the `.miz` and the name listed in the QRA definition match exactly.
- [x] TDD against a real mission folder fixture; ruff + mypy clean.
- [x] Mission-maker catalogue updated.

### Blocked by

FEAT-MCP-MISSION-EDITOR-024 (and shares patterns with 025).

---

## FEAT-MCP-MISSION-EDITOR-027 — `create_cap_mission` (one pass, both worlds)

Status: ✅ done
Type: feat
Files: `src/python/veaf-tools/veaf_mission_mcp/composites.py`, `veaf_mission_mcp/actions.py`, `test/python/`

### What to build

A single action laying down an on-demand CAP mission across both worlds:

1. **Template group** (`add_group` with `late_activation=True`, name `OnDemand-<missionName>`
   — the `as_cap_template` intent or explicit prefix) — the CAP template DCS activates on demand.
2. **`mission.yaml` config** — a `cap_missions:` / `combat_missions:` entry referencing
   `<missionName>` (the build resolves it to the `OnDemand-` group via `group_validation`'s
   `ONDEMAND_CAP_PREFIX`).

Confirm the exact `mission.yaml` shape (`cap_missions:` vs `combat_missions:`) against
`MISSION_YAML_REFERENCE` / `group_validation.py` during implementation.

### Acceptance criteria

- [x] One call produces: the `OnDemand-<name>` Late-Activation template group and the matching
      `cap_missions`/`combat_missions` yaml entry.
- [x] The yaml reference resolves to the `OnDemand-`-prefixed group (matches `group_validation`).
- [x] TDD against a real mission folder fixture; ruff + mypy clean.
- [x] Mission-maker catalogue updated.

### Blocked by

FEAT-MCP-MISSION-EDITOR-024.

---

## FEAT-MCP-MISSION-EDITOR-028 — Wave-8 documentation

Status: ✅ done
Type: docs
Files: `doc/developer/mission-editing-mcp.md` (FR/EN), `doc/mission-maker/AI_ASSISTANT_CATALOG.md` (FR/EN), `CONTEXT.md`, `CHANGELOG.md`, `pyproject.toml`, `plugin/skills/veaf-mission-authoring/SKILL.md`

### What to build

- Developer doc (FR/EN): document folder-awareness and the composite builders
  (`create_combat_zone`, `create_qra`, `create_cap_mission`) — the "one pass, both worlds" model
  and the extract/build round-trip.
- Mission-maker catalogue (FR/EN): a new **top-of-list** theme for the one-shot builders (this is
  the headline capability — high frequency), with worked example phrases.
- CONTEXT.md glossary: a "composite action" / "one-pass builder" entry if warranted.
- Update the `veaf-mission-authoring` skill: prefer the composite when the user asks for a whole
  feature; fall back to primitives otherwise.
- CHANGELOG entry; PATCH version bump.

### Acceptance criteria

- [x] Both language docs and the catalogue describe the composites and the both-worlds model.
- [x] Skill updated to reach for composites first.
- [x] CHANGELOG + version bump landed.

### Blocked by

FEAT-MCP-MISSION-EDITOR-025 / 026 / 027.

---

## FEAT-MCP-MISSION-EDITOR-029 — `scaffold_mission` (bootstrap an empty folder from GitHub)

Status: ✅ done
Type: feat
Files: `src/python/veaf-tools/veaf_mission_mcp/scaffold.py`, `veaf_mission_mcp/actions.py`, `veaf_libs/platform_assets.py`, `test/python/veaf_mission_mcp/test_scaffold.py`

### What to build

A single MCP action that turns an **empty target folder** into a ready VEAF mission folder by
driving the **real VEAF binaries** (decision with David — not re-implementing the updater/prepare
logic in-process), faithful to a maker's own first-run experience.

Parameters:

- `target_folder` (required) — the folder to initialize.
- `template` (required) — `minimal` | `standard` | `full`. `custom` is rejected (its interactive
  TUI picker has no TTY under a subprocess). The template *question* is the calling LLM's job.
- `github_token` (optional) — relayed to the updater via `--token` (bypasses the API rate limit).
- `tag` (optional, default `published-latest`) — relayed to the updater via `--tag`.

Steps:

1. Resolve `target_folder` (create if missing). **Refuse a non-empty folder** with a clear error
   (never scaffold over an existing mission).
2. Resolve the updater asset name for the current OS (Windows: `veaf-tools-updater.exe`; Unix:
   `veaf-tools-updater-<os>-<arch>`), GET it from the **stable release-download URL**
   (`…/releases/download/<tag>/<asset>` — no GitHub API, no rate limit), write it into the folder,
   `chmod +x` on Unix.
3. `subprocess.run` the updater with `cwd=target_folder` (+ `--token`/`--tag` if given). Check the
   return code **and** that `veaf-tools[.exe]` and `published/` appeared.
4. `subprocess.run` `veaf-tools[.exe] prepare --template <template> --force` with `cwd=target_folder`.
   Check the return code.
5. Return a structured summary: `{folder, template, veaf_tools_version, files_installed}` + any
   warnings.

A small cross-OS helper in `platform_assets.py` returns the updater asset name **including Windows**
(`updater_asset_name()` currently returns `None` there — the mapping only covers Unix).

### Acceptance criteria

- [ ] `scaffold_mission` registered in the catalog; `describe_action` returns its schema.
- [ ] Empty folder → updater downloaded, updater run, `prepare` run — in that order, `cwd` = folder.
- [ ] Non-empty folder → refused with an explicit error, nothing downloaded/run.
- [ ] `template` outside `minimal`/`standard`/`full` → rejected before any download.
- [ ] A non-zero exit from the updater **or** from `prepare` surfaces as a clear error (not silent).
- [ ] TDD mocks the download + `subprocess.run` (asserts sequence, exe path, args, cwd, guards,
      failure paths); ruff + mypy clean (full-tree; `scaffold.py` typed from the start — no exclusion).

### Notes

- The action **downloads and executes binaries** — intended and faithful to the real workflow.
  Tests cover the orchestration only (mocked download + subprocess); the real end-to-end network
  run is a manual check by David in a real folder.
- On Windows the updater self-replaces via a deferred `.cmd` after it exits; that runs in the
  background and does not block the subsequent `prepare` (which uses the already-installed
  `veaf-tools.exe`).

---

## FEAT-MCP-MISSION-EDITOR-030 — Wave 9 doc + catalogue + skill

Status: ✅ done
Type: docs
Files: `doc/developer/mission-editing-mcp.md`, `doc/developer/mission-editing-mcp.en.md`, `doc/mission-maker/AI_ASSISTANT_CATALOG.md` (+ `.en.md`), `plugin/skills/veaf-mission-authoring/SKILL.md`, `CHANGELOG.md`, `pyproject.toml`

### What to build

Document the wave-9 scaffolding action across the same surfaces every prior wave updated:

- **Developer doc** (FR + EN): a "Scaffolding (wave 9)" section describing `scaffold_mission`, the
  drive-the-real-binaries decision, the download-updater → run-updater → `prepare` sequence, the
  empty-folder guard, and the `minimal`/`standard`/`full` templates (`custom` unsupported).
- **Mission-maker catalogue** (FR + EN): a `scaffold_mission` entry presented as **step 0** of a
  from-scratch mission (before the wave-8 composites).
- **Authoring skill** (`veaf-mission-authoring`): a "step 0 — create the folder" note, and that the
  assistant must **ask the maker which template** (coverage tier) before calling `scaffold_mission`.
- **CHANGELOG** under `[Unreleased]`; **bump** `pyproject.toml` → 6.9.9.

### Acceptance criteria

- [ ] FR + EN developer doc sections in sync (parity is enforced elsewhere in the repo).
- [ ] Catalogue lists `scaffold_mission` with the step-0 framing, FR + EN.
- [ ] Skill instructs asking the template question before scaffolding.
- [ ] CHANGELOG entry; version bumped; `poetry install` run.

### Blocked by

FEAT-MCP-MISSION-EDITOR-029.

---

## FEAT-MCP-MISSION-EDITOR-031 — Coordinate projection foundation (port) + ADR 0015

Status: ✅ done
Type: feat
Files: `docs/adr/0015-coordinate-projection-port.md`, `src/python/veaf-tools/veaf_libs/coordinates.py`, `test/python/veaf_libs/test_coordinates.py`

### Problem

Placement actions take **DCS local coordinates** (`x`/`y`, metres in the theatre's own projection).
Makers think in lat/long off a map. The DCS `coord.*` conversions live in the **in-game Lua
runtime** and are unavailable design-time; the repo has no Python projection.

### Decision — copy the existing implementation into Python

Copy the tested implementation from Dup's plugin (no shared upstream, no drift-tracking):

- Source: `d:\dev\_dcs-other\bfr-claude-plugins\plugins\dcs-mission-tools\tools\src\lib\projection.lua`
  (**MIT**; original BFR code). VEAF is Apache-2.0 — MIT-compatible; keep a short attribution header.
- It carries the hard part: WGS84 Transverse Mercator forward/inverse **plus per-theatre tables**
  (`lon0`, `x0`, `y0`) for **caucasus, syria, persiangulf, marianaislands**.
- Its test file ships **5 reference cases** `(theatre, x, y, lat, lon)` with tolerances (5e-6° on
  lat/lon, 0.5 m round-trip) — reused verbatim as our Python fixtures.

### What to build

- `veaf_libs/coordinates.py`: straight Python copy — `latlon_to_xy(theatre, lat, lon)` /
  `xy_to_latlon(theatre, x, y)`, the theatre table, unsupported-theatre error (names the theatre,
  case-insensitive), matching the Lua behaviour. Short attribution header crediting
  `bfr-claude-plugins` (MIT).
- ADR 0015: the copy decision, provenance (repo + path + commit), supported theatres, tolerances.

### Acceptance criteria

- [ ] The 5 reference cases pass within the source tolerances (5e-6°, 0.5 m round-trip).
- [ ] `x/y → lat/lon → x/y` round-trips stable on all four theatres.
- [ ] Unsupported theatre → clear error naming it; theatre name case-insensitive.
- [ ] Attribution header present; ADR 0015 accepted.
- [ ] ruff + mypy clean (full-tree; new module typed from the start — no exclusion).

### Out of scope

- **MGRS** — not in the source, not needed now. If a maker ever needs it, add it at its simplest
  later (theatre-independent standard, composed with this projection).

---

## FEAT-MCP-MISSION-EDITOR-032 — `describe_map` + `resolve_coordinates` actions

Status: ✅ done
Type: feat
Files: `src/python/veaf-tools/veaf_mission_mcp/map_tools.py`, `veaf_mission_mcp/actions.py`, `test/python/veaf_mission_mcp/test_map_tools.py`

### What to build

Two read/utility MCP actions giving the LLM map awareness design-time (no DCS running):

- **`describe_map`** (read): from the mission's `.miz`/folder, return the **theatre** name, the
  **bullseye(s)** (per coalition, from `mission.coalition.*.bullseye`), and the existing **trigger
  zones and groups** as reference points (reuse `describe_mission`). Lets the LLM orient itself and
  express positions relative to known anchors.
- **`resolve_coordinates`** (utility): convert a position between `{x,y}` and `{lat,lon}` for the
  mission's theatre, using the ticket-031 conversions. Reads the theatre from the mission so the
  caller never supplies projection parameters. (MGRS out of scope — see ticket 031.)

### Acceptance criteria

- [ ] `describe_map` returns theatre + bullseye(s) + reference zones/groups from a real fixture.
- [ ] `resolve_coordinates` round-trips `{x,y}` ↔ `{lat,lon}` for the fixture's theatre.
- [ ] Both registered in the catalog; `describe_action` returns their schemas.
- [ ] TDD against a real mission fixture; ruff + mypy clean (full-tree).

### Blocked by

FEAT-MCP-MISSION-EDITOR-031 (conversions).

---

## FEAT-MCP-MISSION-EDITOR-033 — Human-coordinate input on placement actions

Status: 🚫 wontfix (deferred — superseded by `resolve_coordinates` + FEAT-GEO-PLACEMENT)

> **Decision (with David).** Once `resolve_coordinates` (ticket 032) exists, embedding `{lat,lon}`
> into every placement action is marginal: the caller converts to `x/y` first, then uses the actions
> unchanged. Real-world *named* placement (the actual need) is handled by the geocoder in
> `FEAT-GEO-PLACEMENT`, which also returns `x/y`. So this ticket is dropped rather than built.

Type: feat
Files: `src/python/veaf-tools/veaf_mission_mcp/add_group.py`, `add_trigger_zone.py`, `composites.py`, `veaf_mission_mcp/` (shared position parser), `test/python/`

### What to build

Let every placement action accept a `position` given in **lat/long** in addition to DCS `x/y`. A
shared helper normalizes a position dict to `{x, y}` before insertion, using the mission's theatre
(via ticket 031):

- `{x, y}` — unchanged (backward compatible; the default).
- `{lat, lon}` — decimal degrees.

Applies to `add_group`, `add_trigger_zone`, and the wave-8 composites (`create_combat_zone`,
`create_qra`, `create_cap_mission`) — anywhere a `position` is taken today. Routes/waypoints accept
the same forms. (MGRS out of scope — see ticket 031.)

### Acceptance criteria

- [ ] Each accepted form (`x/y`, `lat/lon`) places a group/zone at the same spot on the
      fixture theatre (verified by re-reading and comparing x/y within tolerance).
- [ ] Existing `{x,y}` callers are unaffected (regression tests still pass unchanged).
- [ ] Ambiguous/partial position (e.g. `lat` without `lon`) → clear error.
- [ ] TDD per form + theatre-mismatch handling; ruff + mypy clean (full-tree). Any worker touched
      here that still sits under the mypy `ignore_errors` list is dropped from it (quality ratchet).

### Blocked by

FEAT-MCP-MISSION-EDITOR-031 (conversions).

---

## FEAT-MCP-MISSION-EDITOR-034 — Wave 10 doc + catalogue + skill

Status: ✅ done
Type: docs
Files: `doc/developer/mission-editing-mcp.md` (+ `.en.md`), `doc/mission-maker/AI_ASSISTANT_CATALOG.md` (+ `.en.md`), `plugin/skills/veaf-mission-authoring/SKILL.md`, `CONTEXT.md`, `CHANGELOG.md`, `pyproject.toml`

### What to build

Document wave-10 map reading + human coordinates:

- **Developer doc** (FR + EN): a "Map & coordinates (wave 10)" section — `describe_map`,
  `resolve_coordinates`, human-coordinate input on placement actions, and the design-time projection
  approach (link ADR 0015).
- **Mission-maker catalogue** (FR + EN): entries for `describe_map` / `resolve_coordinates` and a
  note that positions can be given as lat/long, not only DCS x/y.
- **Authoring skill**: guidance to prefer human coordinates and to **ask which system** the maker is
  using when they give a position.
- **CONTEXT.md**: glossary entry for theatre projection / DCS local coordinates.
- **CHANGELOG** under `[Unreleased]`; **bump** `pyproject.toml`.

### Acceptance criteria

- [ ] FR + EN developer doc + catalogue in sync.
- [ ] Skill guides the coordinate-system question.
- [ ] CONTEXT glossary entry added; CHANGELOG entry; version bumped; `poetry install` run.

### Blocked by

FEAT-MCP-MISSION-EDITOR-031, 032, 033.

---

## FEAT-MCP-MISSION-EDITOR-035 — `validate_mission` + `build_mission` actions

Status: ✅ done
Type: feat
Files: `src/python/veaf-tools/veaf_mission_mcp/build_tools.py`, `veaf_mission_mcp/actions.py`, `test/python/veaf_mission_mcp/test_build_tools.py`

### What to build

Close the authoring loop so the MCP produces a playable `.miz` without leaving the assistant.

- **`validate_mission(folder_path)`** — call `veaf_libs.mission_validator.validate_mission_folder`
  **in-process**; return `{folder, ok, errors: [msg], warnings: [msg]}` (`ok` = no errors).
- **`build_mission(folder_path)`** — drive `veaf-tools build` via **subprocess** with `cwd=folder`
  (build orchestration lives in the CLI command). Resolve the folder's `veaf-tools[.exe]` (installed
  by `scaffold_mission`), else fall back to `veaf-tools` on PATH. Return `{folder, ok, message}`; a
  non-zero exit is surfaced as a clear `RuntimeError`.

Both registered in the catalog with schemas.

### Acceptance criteria

- [ ] `validate_mission` on a real folder fixture returns errors/warnings correctly (`ok` reflects errors).
- [ ] `build_mission` builds via `veaf-tools build` in the folder (subprocess mocked in tests: asserts
      command, `cwd`, binary resolution, and the non-zero-exit failure path).
- [ ] Both registered; `describe_action` returns their schemas.
- [ ] ruff + mypy clean (new module typed, no exclusion).

---

## FEAT-MCP-MISSION-EDITOR-036 — Wave 11 doc + catalogue + skill

Status: ✅ done
Type: docs
Files: `doc/developer/mission-editing-mcp.md` (+ `.en.md`), `doc/mission-maker/AI_ASSISTANT_CATALOG.md` (+ `.en.md`), `plugin/skills/veaf-mission-authoring/SKILL.md`, `CHANGELOG.md`, `pyproject.toml`

### What to build

- **Developer doc** (FR + EN): a "Build & validate (wave 11)" section — `validate_mission`,
  `build_mission`, and the full create→edit→**validate→build**→play loop.
- **Mission-maker catalogue** (FR + EN): entries for validating and building a mission.
- **Skill**: validate before building; build to produce the playable `.miz`; surface build errors.
- **CHANGELOG**; version bump.

### Acceptance criteria

- [ ] FR + EN docs in sync.
- [ ] Skill guides validate-then-build.
- [ ] CHANGELOG entry; version bumped.

### Blocked by

FEAT-MCP-MISSION-EDITOR-035.

---

## FEAT-MCP-MISSION-EDITOR-037 — Optional explicit unit name (enables `#command`/`#spawn*`)

Status: ✅ done
Type: feat
Files: `src/python/veaf-tools/veaf_mission_mcp/add_group.py`, `veaf_mission_mcp/actions.py`, `test/python/veaf_mission_mcp/`

### Problem

The combat-zone idiom is a fake-unit group whose **unit name** carries `#command="-<alias> ..."`
(also `#spawngroup=`/`#spawnradius=`/`#spawncount=`/`#spawnchance=`/`#spawndelay=`), parsed from the
unit name by `veafCombatZone.lua`. The oracle + skill teach it, but `add_group`/`create_combat_zone`
auto-name every unit and expose only `{type, count}` — so the marker was unbuildable via the MCP.

### What to build

- `_build_units`: if a unit spec has a `name`, use it (verbatim for `count == 1`; suffixed
  `"<name> #NN"` for `count > 1` to keep DCS unit-name uniqueness — the substring marker still
  parses); otherwise keep the current auto-name.
- Add an optional `name` to the `add_group` units item schema, documented as the place to carry a
  combat-zone marker (e.g. `#command="-armor ..."`). Composites inherit it (they pass `units`
  through to `insert_group_into_content` → `_build_units`, no change needed).

### Acceptance criteria

- [ ] A unit spec with `name` produces a unit of that exact name (count 1); count>1 stays unique.
- [ ] No `name` → current auto-name unchanged (regression).
- [ ] A `create_combat_zone` group with a `#command="-armor ..."` fake unit round-trips: the unit
      name is present in the built folder/`.miz`.
- [ ] ruff + mypy clean (full-tree).

---

## FEAT-MCP-MISSION-EDITOR-038 — Wave 12 doc + catalogue + skill

Status: ✅ done
Type: docs
Files: `doc/developer/mission-editing-mcp.md` (+ `.en.md`), `doc/mission-maker/AI_ASSISTANT_CATALOG.md` (+ `.en.md`), `plugin/skills/veaf-mission-authoring/SKILL.md`, `CHANGELOG.md`, `pyproject.toml`

### What to build

- **Developer doc** (FR + EN): note that an `add_group`/composite unit can carry an explicit `name`,
  and that this is how the combat-zone `#command`/`#spawn*` markers are set (they live in the unit
  name). Worked `create_combat_zone` example with a `#command="-armor ..."` fake unit.
- **Catalogue** (FR + EN): mention the `#command` fake-unit idiom is now buildable.
- **Skill**: reinforce reaching for the `#command` fake-unit pattern for combat zones now that the
  action supports it (unit `name`).
- **CHANGELOG**; version bump.

### Blocked by

FEAT-MCP-MISSION-EDITOR-037.
