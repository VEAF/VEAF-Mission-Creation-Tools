# Lot CUSTOM-SCRIPTS-TRIGGERS — unify trigger emission, fix custom_scripts loading

Status: ✅ done

**Goal**: Flogas reported that in 6.5.0 a script declared in `custom_scripts` is parsed (its missing-file warning clears) but is **not loaded in static missions** — no load trigger carries it. Root cause: every VEAF load trigger is emitted twice with duplicated, divergent logic — `insert_veaf_triggers()` (`trig` table) and `insert_veaf_trigrules()` (`trigrules` table, the one DCS executes). The static mission trigger #6 diverged: the `trigrules` form hardcodes only veaf-config + mission-script (omits custom_scripts — the bug), while the `trig` form wrongly includes `veafDynamicConfig.lua` (latent error in static). This duplication also caused C6 (double-spawn).

**Approach** (validated with David): emit BOTH forms from a single per-trigger spec (`VeafTriggerSpec` + `LuaAction`/`FileAction`) so they can never diverge; the static mission trigger and the dynamic `veafDynamicConfig.lua` both use the one ordered list `_ordered_mission_script_names()` (veaf-config → mission-script → custom_scripts; excludes veafDynamicConfig.lua, in one place). Keep `custom_scripts` API as a single `generate_load_trigger` flag (repaired to apply in both modes); mode-specific script sets ("dynamic-only" debug scripts) are handled via build **profiles** (documented). `mission-script.lua` stays auto-loaded first. Annexes: spawn-data trigger kept separate + documented; CTLD-beacons legacy v5 trigger deferred (needs Flogas's exact CTLD/CSAR config). Plan: `C:\Users\David\.claude\plans\federated-churning-pascal.md`.

**Branch**: `feature/custom-scripts-triggers` → PR → `develop`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| CUSTOM-SCRIPTS-TRIGGERS-001 | Unify trig/trigrules emission from a single spec (`_build_veaf_trigger_specs` + `_emit_trig_action_string`/`_emit_trigrule_actions`); fix static #6 to load custom_scripts and exclude veafDynamicConfig.lua; repair `generate_load_trigger`; tests (custom_scripts in both static trigrule & veafDynamicConfig; trig↔trigrules parity; golden #1-5). **Note**: `meters`/`zone` dropped (not preserved) per David's in-session decision, superseding the plan's "preserve" note. | `mission_builder/mission_builder_worker.py`, `test/python/mission_builder/` | fix | ✅ |
| CUSTOM-SCRIPTS-TRIGGERS-002 | Docs: custom_scripts semantics (loads in both modes, order veaf-config → mission-script → custom_scripts) + how to get "dynamic-only"/"static-only" via build profiles (deep-merge replaces lists → repeat base scripts) | `doc/MISSION_YAML_REFERENCE.*` (FR/EN), `CHANGELOG.md` | chore | ✅ |
