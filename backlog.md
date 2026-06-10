# Backlog — VEAF Mission Creation Tools v6

## Legend

- **Type**: `feat` / `fix` / `chore`
- **Status**: `⬜` to do · `🔄` in progress · `✅` done

> Completed lots are moved to [backlog-archive.md](backlog-archive.md).

---

## Summary

| Lot | Status |
|-----|--------|
| Phase 0b — GitHub cleanup | ✅ |
| Lot CI-NODE24 — Migrate GitHub Actions off deprecated Node.js 20 | 🔄 |
| Lot TUI-YAML-DEFAULTS — TUI defaults aware of an existing mission.yaml | ✅ |
| Lot 5 — RELEASE | ⬜ |
| Lot FIX-BUILD-BARE-NAME-PATH — `build` with a bare mission name produces a relative output path, breaking the weather step | ✅ |
| Lot FIX-EXTRACT-COMMUNITY-DICT — `extract` crashes with KeyError on community script dicts | ✅ |
| Lot FIX-I18N-CONVERT-V5 — Hardcoded English messages in convert-v5 | ✅ |
| Lot PREREL-BUGS — pre-release code review findings (briefing over-capture, exit codes, i18n, error handling) | ✅ |
| Lot SECREV — full-repo code review findings (lupa RCE, helicopter extraction data loss, zip hardening, Lua nil-derefs) | ⬜ |
| Lot TODO0609-MODULES-UNIFY — single `modules:` block as source of truth (QRA + community config nested), CTLD/CSAR extracted from v5 | ⬜ |
| Lot TODO0609-CONVERT-FIDELITY — convert-v5 report fidelity: comment full migrated blocks, emit commented-out v5 elements, silenceAtc key | ⬜ |
| Lot TODO0609-ERA-AUTODETECT — auto-detect mission era (incl. WW2) from `.miz` content, manual override wins | ⬜ |
| Lot TODO0609-SPAWN-EXTERNALIZE — externalize spawn group / veafUnits / dcsUnits definitions from Lua to YAML (spike + impl) | ⬜ |
| Lot TODO0609-DYNLOAD-CLARIFY — clarify `veafDynamicConfig.lua` vs `VeafDynamicLoader.lua`, find obsolete one (spike) | ⬜ |
| Lot TODO0609-PRESETS-FIDELITY — iso-functional v5 presets conversion (fix) + presets data-structure/defaults analysis (spike) | ⬜ |
| Lot TODO0609-TRIGGERS-VERIFY — verify DCS trigger migration behaviour for custom scripts (with Flogas) | ⬜ |
| Lot TODO0609-TUI-FOLDER-HINT — clarify the TUI mission-folder default (`.`) | ⬜ |
| Lot TODO0609-AIRCRAFT-INJECT — split aircraft-group injection into spawnable-aircraft vs dynamic-slot-template steps, flag/prefix sort | ⬜ |
| Lot TODO0609-DEFAULTS-AUDIT — audit `defaults/mission-folder` for genuinely-unused leftover files | ⬜ |
| Lot UXPILOT-FEEDBACK — surface command errors to pilots (global pcall guard + unified feedback + unknown-parameter hints) | ⬜ |
| Lot QUALITY-GATE — erode mypy `ignore_errors` and ratchet the coverage gate, one worker per lot | 🔄 |
| Lot SPAWN-REFACTOR — characterize `veafSpawnParser` with tests, then de-duplicate the spawn subsystem | ⬜ |

---

## Lot FIX-BUILD-BARE-NAME-PATH — `build` with a bare mission name produces a relative output path

**Goal**: Running `build` with a bare mission name (instead of a `.miz` file or the default `mission.miz`) left the output mission as a path *relative to the current directory*. The weather step resolves a relative mission path against `versions.yaml`'s parent (`<folder>/src`), so it looked for `<folder>/src/<name>.miz` and aborted with `Base mission not found`. The bug surfaced through the TUI because the mission.yaml-aware default (lot TUI-YAML-DEFAULTS) now pre-fills the real mission name, taking this code path instead of the `== DEFAULT_MISSION_FILE` branch that anchored the path in the mission folder.

**Branch**: `fix/build-bare-name-path` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| FIX-BUILD-BARE-NAME-PATH-001 | Extract output-mission resolution into a testable `_resolve_output_mission` helper that anchors a bare-name `.miz` in the mission folder (absolute) and sanitizes the name, unifying the explicit-name and default+`mission.yaml` paths. Add unit tests covering: default+no yaml, default+yaml name, explicit bare name (regression), explicit `.miz`, unsafe-character sanitization. | `veaf_tools/commands/build.py`, `test/python/` | fix | ✅ |

---

## Lot FIX-EXTRACT-COMMUNITY-DICT — `extract` crashes with KeyError on community script dicts

**Goal**: `veaf-tools extract` raised `KeyError: 1` because `extract_mission` still indexed every script-file entry as a `(path, dest)` tuple, while `get_community_script_files()` was refactored (lot COMM-001) to return dicts. Normalize the iteration so community dicts are handled by their `path`/`dest` keys.

**Branch**: `fix/extract-community-dict` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| FIX-EXTRACT-COMMUNITY-DICT-001 | Normalize the cleanup loop in `extract_mission` to accept both tuple (VEAF/legacy) and dict (community) script descriptors; add an end-to-end regression test extracting a `.miz` that bundles a community script. | `mission_extractor/mission_extractor_worker.py`, `test/python/mission_extractor/test_mission_extractor_worker.py` | fix | ✅ |

---

## Lot SECREV — Full-repo code review findings

**Goal**: Fix the security and correctness defects surfaced by the full-repository code review. Two are release-blocking: arbitrary code execution when parsing any `.miz` file, and silent data loss when extracting helicopter groups.

**Branch**: `fix/secrev-findings` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| SECREV-001 | **RCE**: `luadata.unserialize()` runs `lua.execute(raw)` on untrusted `.miz` content via an unsandboxed lupa runtime. Route `.miz` parsing through the existing pure-Python `_unserialize()` state machine (preferred), or harden the runtime (`register_eval=False`, strip `os`/`io`/`load`/`loadfile`/`dofile`/`package`/`require` from globals, bound `max_memory`). Add regression tests with a malicious `.miz` payload asserting no execution. | `luadata/serializer/unserialize.py`, `mission_tools/miz_tools.py`, `test/python/` | fix | ⬜ |
| SECREV-002 | **Data loss**: helicopter-matching block (lines 1075-1086) is dedented one level, so only the last helicopter group per country is extracted. Re-indent into the `for group` loop. Regression test: extract a mission with ≥2 helicopter groups in one country, assert all present. | `aircrafts_injector/aircrafts_injector_worker.py`, `test/python/` | fix | ⬜ |
| SECREV-003 | Replace `eval()` in the time-expression parser with a safe AST-based arithmetic evaluator (or numeric/operator allowlist); guard against DoS expressions. Tests for valid and rejected inputs. | `weather_injector/utils/time_expression_parser.py`, `test/python/` | fix | ⬜ |
| SECREV-004 | **Zip Slip**: validate every member name before `extractall` (reject absolute paths and entries escaping the destination) in `.miz` extraction and the updater. | `mission_tools/miz_tools.py`, `veaf-tools-updater.py`, `test/python/` | fix | ⬜ |
| SECREV-005 | **Zip-bomb**: cap total uncompressed size and entry count before extracting `.miz` and `published.zip`. | `mission_tools/miz_tools.py`, `veaf-tools-updater.py`, `test/python/` | fix | ⬜ |
| SECREV-006 | `convert_weather` truthiness guards (`if temp := ...`) silently drop legitimate `0` values (temperature, wind speed/direction, visibility). Use `is not None`. Tests for zero-valued weather params. | `mission_builder/v5_pipeline_converters.py`, `test/python/` | fix | ⬜ |
| SECREV-007 | Lua nil-deref crashes: `spawnConvoy` `size / 2` without nil-guard (`veafSpawnGround.lua:635`); `generateAirDefenseGroup` mutates nil group after error (`veafCasMission.lua:763`); `getAtcForCarrierOperations`/`stopCarrierOperations` deref carrier before nil-check (`veafCarrierOperations.lua:662,789`). Add guards + luaunit tests. | `src/scripts/veaf/veafSpawnGround.lua`, `veafCasMission.lua`, `veafCarrierOperations.lua`, `test/lua/` | fix | ⬜ |
| SECREV-008 | `veafAirWaves.addWave` string-list branch inserts the whole `parameter` table instead of element `s` (`veafAirWaves.lua:307`). Fix + test. | `src/scripts/veaf/veafAirWaves.lua`, `test/lua/` | fix | ⬜ |
| SECREV-009 | `veafSecurity`: stop logging the cleartext password at debug (`:552`); fix `isAuthenticated` reading the never-assigned `veafSecurity.SecurityDisabled` instead of `veaf.SecurityDisabled` (`:656`). | `src/scripts/veaf/veafSecurity.lua`, `test/lua/` | fix | ⬜ |
| SECREV-010 | `veafMove.markTextAnalysis` mandatory-group guard never fires (`groupName` defaults to `""`, truthy). Reject empty group name (`veafMove.lua:240`). Fix + test. | `src/scripts/veaf/veafMove.lua`, `test/lua/` | fix | ⬜ |

**Out of scope (need a design decision first, tracked separately)**: remote `login` trusting the server-supplied auth level without password validation (`veafSecurity.lua:427`), and potential shell injection via crafted SRS radio message text (`veafRadio.lua:759`). Both are gated behind L1/server trust; raise with the team before changing the auth model.

---

## Lot CI-NODE24 — Migrate GitHub Actions off deprecated Node.js 20

**Goal**: GitHub Actions will force Node.js 20 actions to run on Node.js 24 starting June 16th, 2026, and remove Node.js 20 from runners on September 16th, 2026. Bump the affected actions to majors that ship a Node.js 24 runtime so the workflows keep working without the deprecation warning.

**Branch**: `chore/ci-node24` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| CI-NODE24-001 | Bump `actions/checkout@v4` → `@v5` in all workflows | `.github/workflows/docs.yml`, `python-quality.yml`, `release.yml`, `lua-ci.yml` (×3), `sbom.yml`, `secret-scanning.yml` | chore | ✅ |
| CI-NODE24-002 | Bump `actions/setup-python@v5` → `@v6` in all workflows | `.github/workflows/docs.yml`, `python-quality.yml`, `release.yml`, `sbom.yml` | chore | ✅ |
| CI-NODE24-003 | Bump Node.js 20 actions to their first Node.js 24 major: `actions/upload-artifact@v4`→`@v6` (v5 still defaults to Node 20; v6 is `runs.using: node24`), `JohnnyMorganz/stylua-action@v4`→`@v5`, `softprops/action-gh-release@v2`→`@v3`, `gitleaks/gitleaks-action@v2`→`@v3`. `snok/install-poetry@v1` left as-is (composite action — no Node runtime, unaffected). | `.github/workflows/python-quality.yml`, `sbom.yml`, `lua-ci.yml`, `secret-scanning.yml` | chore | ✅ |
| CI-NODE24-004 | Trigger each workflow (or wait for natural runs) and confirm the Node.js 20 deprecation annotation no longer appears | CI runs | chore | 🔄 |

**Behavioral-change review (third-party major bumps)**: each cross-major bump was checked against its upstream release notes and confirmed to be a **runtime-only** Node 20→24 migration for our usage — no new defaults or flags affect these workflows: `stylua-action@v5` (Node 24 only; same `version`/`args` inputs), `action-gh-release@v3` (Node 24 only; v2 stays on Node 20), `gitleaks-action@v3` (Node 24 only; same `GITLEAKS_*` env contract). `upload-artifact@v6` keeps the v4 single-immutable-artifact-per-name semantics our steps already rely on (the v7 non-zipped-artifact change is opt-in and not adopted here).

> **SHA pinning** (Sourcery suggestion): not done. The repo consistently uses floating major-version tags for every action; switching to commit-SHA pinning is a repo-wide supply-chain-hardening convention change, out of scope for this Node-runtime maintenance lot. Tracked as a possible future lot if the team wants it.

---

## Lot TUI-YAML-DEFAULTS — TUI defaults aware of an existing mission.yaml

**Goal**: When `veaf-tools` is launched in TUI mode, the proposed argument defaults are currently static (`mission.miz`, `.`, …) or the last saved value. They ignore a `mission.yaml` present in the working directory. The wizard should detect an existing `mission.yaml` and derive smarter defaults from it — at least for the mission name prompt.

**Branch**: `feat/tui-yaml-defaults` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| TUI-YAML-DEFAULTS-001 | When a `mission.yaml` exists in the working directory, the TUI derives the default for the `mission_name_or_file` prompt from its `mission.name` field instead of the static `mission.miz`. The `mission:` block already exists in the schema (`mission.name` → `veaf.config.MISSION_NAME`, emitted by `convert-v5` and read by `lua_config_generator`); reuse it as the source of truth. | `veaf_libs/tui.py`, `test/python/` | feat | ✅ |
| TUI-YAML-DEFAULTS-002 | Establish the default-resolution precedence and make it explicit: last saved preference > value derived from `mission.yaml` (`mission.name`) > static fallback (decide whether a saved preference should override a detected `mission.yaml` or the reverse). Cover with unit tests. | `veaf_libs/tui.py`, `veaf_libs/preferences.py`, `test/python/` | feat | ✅ |
| TUI-YAML-DEFAULTS-003 | Extend the `mission.yaml`-aware defaults to the other relevant prompts where it makes sense (e.g. `mission_folder`, `mission.export_path`, presets/template file paths) once the mechanism from -001/-002 is in place. | `veaf_libs/tui.py`, `test/python/` | feat | ✅ |

> Note: the `mission:` identity block already exists in the `mission.yaml` schema (`name`, `era`, `export_path`, `language`). `mission.name` (e.g. `Training-Syrie`) is the runtime mission name; it is the natural source for the mission-name prompt default. No new schema key is required.

> Resolution: precedence is **last saved preference > `mission.yaml` (`mission.name`) > static fallback** — a saved value the user explicitly typed last run wins over the detected file. Implemented as two pure helpers in `veaf_libs/tui.py` (`_mission_yaml_defaults`, `_resolve_prompt_default`) wired into `run_wizard`. For -003, `mission.name` is the only `mission.yaml` field that maps to an existing prompt (the other prompts — `mission_folder`, presets/template paths — have no `mission.yaml` source); the mechanism is generic (keyed by prompt name) so future fields are a one-line addition.

---

## Phase 0b — GitHub cleanup

Close issues identified during triage. **Verify each one before closing.**
Originally planned as direct commits on `develop-v6` (no code change), but the
backlog status update was delivered through PR #405 because the closing session
was constrained to a working branch.

| # | Ticket | Type | Status |
|---|--------|------|--------|
| CLOSE-001 | Close WONTFIX issues: #55, #146, #147, #180, #193, #246 | chore | ✅ |
| CLOSE-002 | Close STALE issues: #9, #19, #41, #167 | chore | ✅ |

<details>
<summary>Issues to close</summary>

**WONTFIX — Already implemented or out of scope**

| # | Title | Reason |
|---|-------|--------|
| #55 | Faire un système de zone de combat dynamique | Already implemented → `veafCombatZone` |
| #146 | CTLD JTAC 9-line | External project (CTLD/Ciribob) |
| #147 | CTLD JTAC Ask for wind/speed correction | External project (CTLD/Ciribob) |
| #180 | AirWaves - forcer à rester dans la zone | Both tasks already checked ✅ in the issue |
| #193 | CTLD - gestion d'emport multiple de caisses | Requires upstream PR to CTLD, out of scope |
| #246 | CTLD - orientation des unités Patriot | CTLD external bug, out of scope |

**STALE — No activity, too vague, or superseded**

| # | Title | Reason |
|---|-------|--------|
| #9 | Marker command to build a transport mission interception | 2018, no activity since 2021, too vague |
| #19 | Idée - spawn facile avec inventaire des unités par coalition | 2020, informal idea, no spec |
| #41 | Tester spawn humains CASE 1 téléportés à la bonne position | 2021, vague, no activity |
| #167 | Tester gRPC | 2023 tech spike, no follow-up planned |

</details>

---

## Lot 5 — RELEASE: v6.1.0

**Goal**: Merge v6 to master and publish the official release.
**From**: `develop-v6` directly

| # | Ticket | Type | Depends on | Status |
|---|--------|------|------------|--------|
| REL-001 | Finalize `CHANGELOG.md` for v6.1.0 | chore | Lots 1–4 | ⬜ |
| REL-002 | Write `RELEASE_NOTES.md` for v6.1.0 | chore | REL-001 | ⬜ |
| REL-003 | Squash merge `develop-v6` → `master` | chore | REL-002 | ⬜ |
| REL-004 | Tag `v6.1.0` + publish GitHub (`veaf-build publish`) | chore | REL-003 | ⬜ |
| REL-005 | Change doc URL prefix from `/dev/` to `/latest/` in `v5_converter.py` (`DOC_BASE`, `_DOC_BASE`) and `src/defaults/mission-folder/mission.yaml` | chore | REL-003 | ⬜ |

---

## Lot PREREL-BUGS — Pre-release code review findings

**Goal**: Fix bugs found during a verified pre-release code review (unrelated to the documentation lot). These block the next `develop-v6` release. B1 is a functional regression and should be fixed first.

**Branch**: `fix/prerel-bugs` → PR → `develop-v6` (Python changes; separate from the doc PR)

| # | Ticket | Type | Status |
|---|--------|------|--------|
| PREREL-001 (B1) | **Regression** — `config_migrator.py` `_lua_extract_string()` over-collects quoted strings after `:setBriefing(`: a briefing absorbs following setter strings in the same call chain. Introduced by the multiline fix (PR #390), reproduced empirically. Fix: bound the search to the matching `)` of `:setBriefing(`. Add a regression test covering a chained `:setBriefing("..."):setX("...")` case. | fix | ✅ |
| PREREL-002 (B2) | `mission_builder_worker.py` (~L339): `exit()` returns code 0 after a fatal error, so a failed build is reported as success. Use a non-zero exit code / raise. | fix | ✅ |
| PREREL-003 (B3/B4) | Hardcoded English in `mission_builder_worker.py`: ~L333-338 missing-files message and ~L1168 `"Injecting dcs-bridge.lua"` spinner must use `t()`; add FR translations to `fr.json`. | fix | ✅ |
| PREREL-004 (I1) | `paths.py`: replace `exit(-1)` with a raised exception (utility code should not call `exit()`; makes it testable). | fix | ✅ |
| PREREL-005 (cosmetic) | `v5_converter.py` (~L885): remove the dead `is None` branch (never reached). Low priority. | chore | ✅ |

---

## Lot TODO0609-MODULES-UNIFY — Single `modules:` block as the source of truth

**Goal**: Today a module/community-script can appear in up to three places in `mission.yaml`: a toggle under `modules:`, a detailed block under `external_modules:`, and a top-level `qra:` block. Collapse everything into a single `modules:` block where each module has one entry with its config nested (Skynet, CTLD, CSAR, QRA included). Remove `external_modules:` and the top-level `qra:`. **Hard break** — v6 is not officially released yet, so no backward-compatibility shim. Covers todo-2026.06.09 items 5, 6, 8.

**Decisions** (grilling 2026-06-10): everything nested under `modules:`; remove `external_modules:`/`qra:`; hard break (no deprecation); `convert-v5` extracts CTLD/CSAR config from v5. See `docs/adr/0001-modules-single-source-of-truth.md`.

**Branch**: `feat/modules-unify` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| MODULES-UNIFY-001 | Redesign the `mission.yaml` schema: one `modules:` block, each module/community-script an entry with nested config (incl. `skynet`, `ctld`, `csar`, `qra`). Update the default template and the validator. | `src/defaults/mission-folder/mission.yaml`, `veaf_libs/yaml_validator.py` | feat | ⬜ |
| MODULES-UNIFY-002 | `lua_config_generator`: read nested per-module config from `modules:`; drop all handling of `external_modules:` and top-level `qra:`. | `veaf_libs/lua_config_generator.py`, `test/python/` | feat | ⬜ |
| MODULES-UNIFY-003 | `convert-v5`: emit converted modules (incl. QRA) into the new nested `modules:` structure instead of separate `external_modules:`/`qra:` sections. | `mission_builder/config_migrator.py`, `mission_builder/v5_converter.py`, `test/python/` | feat | ⬜ |
| MODULES-UNIFY-004 | `convert-v5`: extract CTLD/CSAR config from `missionConfig.lua` (`ctld.xxx = …` / `csar.xxx = …` assignments) into `modules.CTLD` / `modules.CSAR`. (todo item 6) | `mission_builder/config_migrator.py`, `test/python/` | feat | ⬜ |
| MODULES-UNIFY-005 | Update docs: `doc/MISSION_YAML_REFERENCE.md` (+ `.fr`), migration guide, and any example referencing `external_modules:`/`qra:`. | `doc/MISSION_YAML_REFERENCE*.md`, `doc/mission-maker/MIGRATION_GUIDE*.md` | chore | ⬜ |
| MODULES-UNIFY-006 | Add **semantic** validation of the unified `modules:` block — distinct from the YAML *syntax* validation already provided by `yaml_validator.validate_yaml_file`. Today `lua_config_generator` reads `modules:` as raw nested dicts with silent `.get(key, default)` (`:349-458`), so an unknown module key, an unrecognized `init:` parameter, or a wrong scalar type is silently dropped and produces wrong Lua with no warning to the mission-maker. Validate: unknown module key → error, unrecognized `init:` param → warning, wrong type → error. Reuse the localized `ValidationError` style already rolled out in `aircrafts_injector_worker` (`:31`, `:114-297`) for consistency; consider promoting it (and the existing `weather_injector/models/` config models) toward a shared typed `mission.yaml` model. | `veaf_libs/yaml_validator.py`, `veaf_libs/lua_config_generator.py`, `test/python/` | feat | ⬜ |

---

## Lot TODO0609-CONVERT-FIDELITY — convert-v5 report & extraction fidelity

**Goal**: Make the `convert-v5` annotated report (`convert-v5-report.md`) and YAML output faithfully reflect what was migrated, so the mission-maker can spot at a glance the v5 code that was NOT auto-migrated and decide what to do (migrate by hand, report a bug, move to `mission-script.lua`). Covers todo-2026.06.09 items 4, 9, 10.

> Depends on TODO0609-MODULES-UNIFY for the target YAML shape that commented-out elements (-001) are emitted into.

**Branch**: `feat/convert-fidelity` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| CONVERT-FIDELITY-001 | Re-parse commented-out v5 elements (any extractable module, e.g. a commented `combatZone_Abu_al_Duhur`) and re-emit them as **commented** YAML in `mission.yaml`, instead of silently dropping them. (todo item 4) | `mission_builder/config_migrator.py`, `mission_builder/v5_converter.py`, `test/python/` | feat | ⬜ |
| CONVERT-FIDELITY-002 | In the annotated `missionConfig`, comment out the **entire** `if veafXxx then … end` init block of a migrated module (not only the `initialize()` line), so non-migrated code visually stands out. (todo item 9) | `mission_builder/config_migrator.py`, `test/python/` | feat | ⬜ |
| CONVERT-FIDELITY-003 | Add `mission.silence_atc_on_all_airbases` to the default `mission.yaml` (value `true`) and emit the corresponding Lua. At conversion, scan `missionConfig.lua` for an active `veaf.silenceAtcOnAllAirbases()` call → `true`, else `false`. (todo item 10) | `src/defaults/mission-folder/mission.yaml`, `veaf_libs/lua_config_generator.py`, `mission_builder/config_migrator.py`, `test/python/` | feat | ⬜ |
| CONVERT-FIDELITY-004 | Prepend a numeric summary header to `convert-v5-report.md` (e.g. "N modules migrated · M need manual action (lines …)") so the mission-maker sees at a glance whether work remains, without reading the full annotated config. Drives off the same data the annotation pass already computes. | `mission_builder/v5_converter.py`, `mission_builder/config_migrator.py`, `test/python/` | feat | ⬜ |

---

## Lot TODO0609-ERA-AUTODETECT — Automatic mission era detection

**Goal**: The mission era (especially `WW2`) is currently manual or extracted from v5 only if present. Add automatic detection from the `.miz` content when `era` is not provided. A manual `mission.yaml` `era` always wins. Covers todo-2026.06.09 item 7.

**Decision** (grilling 2026-06-10): combined heuristic — mission year **and** WW2-era unit/aircraft types — with a `mission.yaml` override that always takes precedence.

**Branch**: `feat/era-autodetect` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| ERA-AUTODETECT-001 | Detection helper combining the DCS mission year and a WW2 unit/aircraft-type reference list to infer the era; document the priority rule. Unit tests over fixtures (WW2 by year, WW2 by units, modern, ambiguous). | `mission_builder/`, `test/python/` | feat | ⬜ |
| ERA-AUTODETECT-002 | Wire the helper into conversion/build: use detected era only when `mission.yaml` `era` is absent; manual value always wins. Maintain the WW2-era types reference table. | `mission_builder/config_migrator.py` / `mission_builder/mission_builder_worker.py`, `test/python/` | feat | ⬜ |

---

## Lot TODO0609-SPAWN-EXTERNALIZE — Externalize spawn group definitions to YAML

**Goal**: Move spawn-related definitions out of hand-edited Lua into YAML. Scope: the `veafUnits.GroupsDatabase` / `veafUnits.UnitsDatabase` and `dcsUnits.lua` (all produced by ad-hoc Lua generator scripts that must be adapted), **and especially** per-mission spawn group definitions used by the `_spawn group` command. Large, runtime-impacting; starts with a spike. Covers todo-2026.06.09 item 1.

> **Boundary** (HANDOFF §6): this is the *generate-a-Lua-base* axis (A + `veafUnits`), explicitly **out of scope** of TODO0609-AIRCRAFT-INJECT (the *inject-groups* axis, B + C). Do not seek a unified A↔B/C group schema; the two chantiers are factored along the pipeline axis, not "it's a group".

**Branch**: `feat/spawn-externalize` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| SPAWN-EXTERNALIZE-001 (spike) | Design note: target YAML shape for unit/group definitions; how the Lua runtime consumes it (static vs dynamic loading); how the ad-hoc generator scripts that build `veafUnits` / `dcsUnits.lua` are adapted; per-mission override mechanism for `_spawn group`. Deliverable: reco + implementation tickets. | `src/scripts/veaf/veafUnits.lua`, `dcsUnits.lua`, generator scripts | spike | ⬜ |
| SPAWN-EXTERNALIZE-002 | Implement per the spike (placeholder — split into concrete tickets once -001 lands). | TBD | feat | ⬜ |

---

## Lot TODO0609-DYNLOAD-CLARIFY — Clarify dynamic script loading

**Goal**: Understand and document the two dynamic-loading files — `VeafDynamicLoader.lua` (loads VEAF scripts) and `veafDynamicConfig.lua` (loads mission scripts) — determine whether one is obsolete, and clarify the overall static-vs-dynamic loading of VEAF scripts (including how `convert-v5` handles legacy v5 dynamic-loading triggers). Covers todo-2026.06.09 item 2.

**Branch**: `chore/dynload-clarify` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| DYNLOAD-CLARIFY-001 (spike) | Trace and document both files' roles and the static/dynamic loading flow; identify any obsolete artifact and propose its removal; document the conversion behaviour for legacy dynamic-loading triggers. Deliverable: doc update + cleanup tickets if needed. | `src/defaults/mission-folder/src/scripts/veafDynamicConfig.lua`, `src/scripts/veaf/VeafDynamicLoader.lua`, `mission_builder/mission_builder_worker.py`, `doc/` | spike | ⬜ |

---

## Lot TODO0609-PRESETS-FIDELITY — Iso-functional radio presets conversion

**Goal**: v5 presets encode DCS module quirks (e.g. Mi-24 channel 0 mapped to channel 20 on injection, AJS-37 offsets). The current `convert-v5` loses these. First make conversion iso-functional with the v5 mission; then analyse whether the v6 `presets.yaml` data structure is adequate (the v5 structure may have been better) and propose enriched defaults. Covers todo-2026.06.09 item 13.

**Branch**: `fix/presets-fidelity` → PR → `develop-v6` (13a); follow-up branch for 13b once the spike lands

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| PRESETS-FIDELITY-001 (13a) | Make `convert-v5` produce a `presets.yaml` iso-functional with the v5 mission's presets — preserve per-module channel mappings/offsets (Mi-24 ch0→20, AJS-37, …). Regression tests against real v5 preset fixtures. | `mission_builder/v5_pipeline_converters.py`, `presets_injector/`, `test/python/` | fix | ⬜ |
| PRESETS-FIDELITY-002 (13b, spike) | Analyse the v6 `presets.yaml` data structure vs the v5 presets structure; decide whether to redesign it; propose a default `presets.yaml` that accounts for DCS module quirks. Deliverable: reco + tickets. | `presets_injector/`, `src/defaults/mission-folder/src/presets.yaml` | spike | ⬜ |

---

## Lot TODO0609-TRIGGERS-VERIFY — Verify trigger migration for custom scripts

**Goal**: DCS trigger migration is automatic (`build --migrate-from-v5`). Verify with Flogas the behaviour of triggers for **custom scripts** (custom-script loading) and confirm nothing is lost or mis-handled. Covers todo-2026.06.09 item 3. External dependency: Flogas's input/missions.

**Branch**: `chore/triggers-verify` (only if changes are needed) → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| TRIGGERS-VERIFY-001 | Verify, with Flogas, how custom-script triggers are migrated by `build --migrate-from-v5`; document findings; open fix tickets if a defect is confirmed. | `mission_builder/mission_builder_worker.py`, `doc/` | chore | ⬜ |

---

## Lot TODO0609-TUI-FOLDER-HINT — Clarify the TUI mission-folder default

**Goal**: In the TUI, the mission-folder prompt shows a bare `.` default, which is not obviously the current directory. Add an explanatory label and show the resolved absolute path. Covers todo-2026.06.09 item 11.

**Branch**: `feat/tui-folder-hint` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| TUI-FOLDER-HINT-001 | Enrich the mission-folder prompt: explanatory label (`. = current folder`, FR/EN) and display the resolved absolute path as a hint. Update locales and tests. | `veaf_libs/tui.py`, locales, `test/python/` | feat | ⬜ |

---

## Lot TODO0609-AIRCRAFT-INJECT — Split aircraft-group injection (spawnable vs dynamic-slot template)

**Goal**: Restore the historically-distinct handling of two separate uses of injected aircraft groups that was half-lost in the Python rewrite: **(B) spawnable aircraft groups** cloned at runtime by `veafSpawn` (name prefix `veafSpawn-`) and **(C) dynamic-slot templates** consumed natively by DCS (`dynSpawnTemplate == true`). Two separate, independently-configurable pipeline steps; reliable flag/prefix-based sorting. Source: `HANDOFF-aircraft-groups-injection.md`. This is the analysis behind todo-2026.06.09 item 12 (the defaults files are legitimate and kept; `spawnables.yaml` "doesn't serve" because no step injects it — a pipeline bug).

**Frozen decisions** (see `CONTEXT.md` and `docs/adr/0002-aircraft-group-injection-sort-criteria.md`): two distinct features sharing one extract/inject tool; sort by `dynSpawnTemplate` flag (priority) then `veafSpawn-` prefix, else ignore; **drop the legacy `.*[tT]emplate.*` name sort** (root cause of the historical misrouting bug).

**Branch**: `feat/aircraft-inject` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| AIRCRAFT-INJECT-001 | Replace the single `aircraft_groups` pipeline step with two: `spawnable_aircrafts` (→ `src/spawnables.yaml`) and `dynamic_slot_templates` (→ `src/dynamic-templates.yaml`), each independently configurable (`true/false` or `{enabled, file, mode}`). Decide hard-break vs compat for the old step / `aircraft-templates.yaml`/`templates.yaml` names (ADR 0001 precedent favours a clean hard break). | `veaf_tools/commands/build.py`, `mission_builder/mission_builder_worker.py`, `test/python/` | feat | ⬜ |
| AIRCRAFT-INJECT-002 | Keep both default files in `src/defaults/mission-folder/src/` — `spawnables.yaml` (B) and the renamed (C) file; update the defaults mapping + `test/python/mission_builder/test_mission_builder_defaults.py`. | `src/defaults/mission-folder/src/`, `mission_builder/mission_builder_worker.py`, `test/python/` | feat | ⬜ |
| AIRCRAFT-INJECT-003 | Implement the flag/prefix sort in the extractor (route each group to B or C, ignore the rest); ideally one extraction pass emitting both files (or a `--kind` flag — to arbitrate). **Includes the helicopters indentation bug** (`find_matching_groups` ~L1070-1086): same defect as SECREV-002 — coordinate so it is fixed once, not twice. | `aircrafts_injector/aircrafts_injector_worker.py`, `test/python/` | fix | ⬜ |
| AIRCRAFT-INJECT-004 | Two injection steps, each injecting its file as-is (no name regex); verify `add`/`replace` mode per step. | `aircrafts_injector/aircrafts_injector_worker.py`, `test/python/` | feat | ⬜ |
| AIRCRAFT-INJECT-005 | `convert-v5`: produce **both** v6 files from the v5 `settings.lua`, applying the same flag/prefix sort; update `V5_PIPELINE_CANDIDATES` / `V6_PIPELINE_CANDIDATES`. | `mission_builder/v5_pipeline_converters.py`, `mission_builder/v5_converter.py`, `test/python/` | feat | ⬜ |
| AIRCRAFT-INJECT-006 | Cleanup: fix the dead `.vscode/launch.json` reference (`settings-templates.lua`); realign `doc/mission-maker/scripts/veafSpawn.md` (+ `.en`), `doc/MISSION_YAML_REFERENCE*.md`, `doc/PIPELINE_REFERENCE.md` on the real schema + the B/C distinction. | `.vscode/launch.json`, `doc/` | chore | ⬜ |

**Open questions to settle with David** (handoff §7): (1) canonical name for the (C) file (`dynamic-templates.yaml` / `dynamic-slot-templates.yaml`?); (2) canonical pipeline step names; (3) hard break vs compat on `aircraft_groups`/`aircraft-templates.yaml`; (4) extraction: one pass → two files, or two `--kind` invocations; (5) bonus warehouse wiring (handoff §5: `dynSpawnTemplate` groups also need the `.miz` `warehouses` file to reference them for DCS to offer them as Dynamic Slots) — this lot or a separate one.

---

## Lot TODO0609-DEFAULTS-AUDIT — Audit the defaults mission-folder for dead files

**Goal**: `prepare` copies the whole `src/defaults/mission-folder/` tree into a new mission via `rglob` (`prepare.py:68`), so any leftover file ships to users. The aircraft YAML files are legitimate (see TODO0609-AIRCRAFT-INJECT). Audit the rest to confirm nothing else is dead weight. Covers todo-2026.06.09 item 12.

**Branch**: `chore/defaults-audit` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| DEFAULTS-AUDIT-001 | Audit each file under `src/defaults/mission-folder/` for whether it is actually consumed at first build (candidates to verify: `src/presets.md`, `src/README-versions.md`, `src/options`). Report role + used/unused per file; remove or document anything genuinely dead. Exclude the aircraft YAML (owned by TODO0609-AIRCRAFT-INJECT). | `src/defaults/mission-folder/`, `doc/` | chore | ⬜ |

---

## Lot UXPILOT-FEEDBACK — Surface command errors to pilots

**Goal**: A pilot who mistypes an F10 marker command usually gets **no feedback**, and error surfacing is inconsistent across modules. `veafSpawnAircraft` (`:67`) and `veafShortcuts` (`:625`) call `trigger.action.outText(...)`, but `veafNamedPoints.executeCommand` returns `false` silently and `veafSpawnParser` silently ignores unrecognized parameters (47-rule if-chain). A handler that crashes only logs to the DCS log — invisible in-game. Establish one feedback path and a global safety net so pilot mistakes and runtime errors are always visible.

**Branch**: `feature/uxpilot-feedback` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| UXPILOT-001 | **Global safety net**: wrap the marker-command dispatch in the `veafMarkers` event handlers in `pcall`; on error, show a short localized `outText` to the placing pilot and log the stack via `veaf.loggers`. luaunit test simulating a handler that raises. | `src/scripts/veaf/veafMarkers.lua`, `test/lua/` | feat | ⬜ |
| UXPILOT-002 | **Unified feedback helper**: add `veaf.reportToPilot(message, duration)` (thin, test-safe wrapper over `trigger.action.outText`) and route currently-silent parse failures through it — starting with `veafNamedPoints.executeCommand` (returns `false` with no message). | `src/scripts/veaf/veaf.lua`, `src/scripts/veaf/veafNamedPoints.lua`, `test/lua/` | feat | ⬜ |
| UXPILOT-003 | **Unknown-parameter hints**: in `veafSpawnParser`, when a marker parameter key is not recognized, warn the pilot via `veaf.reportToPilot` and suggest the nearest known key (simple edit-distance over the known-keys list). Depends on UXPILOT-002 and on **SPAWN-REFACTOR-001** (characterization tests must exist first). | `src/scripts/veaf/veafSpawnParser.lua`, `test/lua/` | feat | ⬜ |

---

## Lot QUALITY-GATE — Erode mypy exclusions and ratchet the coverage gate

**Goal**: Two quality guards are advertised but neutralized where it matters. `pyproject.toml:102-120` sets `ignore_errors = true` for **every large worker** (`aircrafts_injector_worker`, `mission_builder_worker`, `mission_converter_worker`, `presets_*`, `waypoints_*`, `weather_*`), so mypy only type-checks already-clean small files — exactly where the SECREV defects did *not* hide. Line coverage is **16%** with `--cov-fail-under=15`, so the gate protects nothing. Turn both into a debt eroded lot-by-lot rather than a single big-bang. Supersedes the archived single-shot attempt (`backlog-archive.md` "Retirer `ignore_errors`…").

**Branch**: `chore/quality-gate` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| QUALITY-001 | Remove `ignore_errors` for the simplest still-excluded workers (start with `presets_injector_worker`, `waypoints_injector_worker`), fix the surfaced type errors, leave the rest. | `pyproject.toml`, touched workers, `test/python/` | chore | ⬜ |
| QUALITY-002 | Document the ratchet policy in `CLAUDE.md` §3: every lot that substantially touches an excluded worker drops its `ignore_errors` entry as part of its Definition of Done; every lot that adds tests bumps `--cov-fail-under` so the gate never sits more than ~2 pts below actual coverage. | `CLAUDE.md`, `pyproject.toml` | chore | ✅ |

> Cross-cutting reminder: the worker-reopening lots (MODULES-UNIFY, AIRCRAFT-INJECT, CONVERT-FIDELITY, SECREV) should each drop the touched worker's mypy exclusion as part of their own work, so this lot only mops up the remainder.

---

## Lot SPAWN-REFACTOR — Characterize then de-duplicate the spawn subsystem

**Goal**: The spawn subsystem — `veafSpawnParser` (656 l., 47 parameter rules), `veafSpawnAircraft` (1486 l.), `veafSpawnGround` (1034 l.) — carries heavy copy-paste (repeated parameter validation, ~15-line debug-log blocks duplicated verbatim, 30+ repetitive default-option blocks) and has **zero luaunit tests** despite being the most complex, most pilot-facing code. Lock current behaviour with characterization tests **first**, then de-duplicate safely.

> **Coordination**: TODO0609-SPAWN-EXTERNALIZE and TODO0609-AIRCRAFT-INJECT reopen these same files. De-duplicate **there**, within those lots' scope, rather than twice — this lot may be folded into SPAWN-EXTERNALIZE once -001 lands. Respect `CLAUDE.md` §2 RULE N°1 (no refactor outside a lot already touching the file).

**Branch**: `refactor/spawn-subsystem` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| SPAWN-REFACTOR-001 | Characterization tests for `veafSpawnParser.markTextAnalysis`: 30+ marker variants incl. typos, missing values, and multiple parameters; lock current behaviour before any change. Prerequisite for UXPILOT-003 and for any dedup. | `test/lua/test_veafSpawnParser.lua` (new) | feat | ⬜ |
| SPAWN-REFACTOR-002 | Extract a spawn-type **descriptor table** (`{type → {defaults, validators}}`) consumed by the parser, and a shared `VeafSpawner` base for the duplicated validation/debug blocks. Only within the scope of a lot already touching these files. | `src/scripts/veaf/veafSpawnParser.lua`, `veafSpawnAircraft.lua`, `veafSpawnGround.lua`, `veafSpawnCore.lua`, `test/lua/` | refactor | ⬜ |

---
