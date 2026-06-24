# Lot TODO0609-SPAWN-EXTERNALIZE — Externalize spawn group definitions to YAML

Status: ✅ done

**Goal**: Move spawn-related definitions out of hand-edited Lua into YAML. Scope: the `veafUnits.GroupsDatabase` / `veafUnits.UnitsDatabase` and `dcsUnits.lua` (all produced by ad-hoc Lua generator scripts that must be adapted), **and especially** per-mission spawn group definitions used by the `_spawn group` command. Large, runtime-impacting; starts with a spike. Covers todo-2026.06.09 item 1.

> **Boundary** (HANDOFF §6): this is the *generate-a-Lua-base* axis (A + `veafUnits`), explicitly **out of scope** of TODO0609-AIRCRAFT-INJECT (the *inject-groups* axis, B + C). Do not seek a unified A↔B/C group schema; the two chantiers are factored along the pipeline axis, not "it's a group".

**Branch**: `feat/spawn-externalize` → PR → `develop-v6`

**Spike result (001 ✅)** — see [ADR 0005](docs/adr/0005-spawn-data-externalization.md):

- Source of truth = **YAML**; the Lua tables (`veafUnits.UnitsDatabase` / `GroupsDatabase`) are **generated**. Two sources: shipped `veaf-units.yaml` (framework) + per-mission `src/spawn-groups.yaml`.
- Generation happens at the **mission build (`veaf-tools build`)** — a new pipeline step merges framework + mission YAML, renders a Lua data module, injects it into the `.miz`. (Differs from `dcsUnits`, which `veaf-build` regenerates into a committed file — here the per-mission overrides only exist at mission-build time.) DCS can't parse YAML at runtime, so the injected module assigns the Lua tables, loaded after the framework bundle (which now defaults them empty).
- `dcsUnits.lua` is **already** externalized (DCSDATA-008) — out of scope.

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| SPAWN-EXTERNALIZE-001 (spike) | Design note (see ADR 0005): YAML shape, mission-build YAML→Lua generation, per-mission override mechanism. Deliverable: reco + tickets. | `docs/adr/0005-…`, `backlog.md` | spike | ✅ |
| SPAWN-EXTERNALIZE-002 | Extract the framework `UnitsDatabase` + `GroupsDatabase` from `veafUnits.lua` into a shipped `veaf-units.yaml`; build a Lua emitter; **parity-check** the generated Lua is semantically equal to today's tables (oracle, like DCSDATA-008); then default the in-`veafUnits.lua` tables to empty. | `src/scripts/veaf/veafUnits.lua`, `veaf-units.yaml`, emitter, `test/` | feat | ✅ |
| SPAWN-EXTERNALIZE-003 | New `veaf-tools build` pipeline step: render the spawn-data Lua from the shipped `veaf-units.yaml` and inject it into the `.miz`; runtime populates `veafUnits.*` after the framework loads. End-to-end test (built `.miz` has the data; `_spawn group <alias>` resolves). | `veaf_tools/commands/build.py`, new worker, `mission_builder/`, `test/python/` | feat | ✅ |
| SPAWN-EXTERNALIZE-004 | Per-mission `src/spawn-groups.yaml` (+ optional `src/spawn-units.yaml`): merge over the framework data (alias collision → mission wins), so `_spawn group <custom>` works. Commented default + FR/EN docs + tests. | `warehouses_injector`-style worker, `src/defaults/`, `doc/`, `test/python/` | feat | ✅ |
| SPAWN-EXTERNALIZE-005 (= SPAWN-REFACTOR-002) | De-duplicate the spawn subsystem (shared validation/debug blocks, descriptor table) now that data is external and the parser is characterized. | `src/scripts/veaf/veafSpawn*.lua`, `test/lua/` | refactor | ✅ |
