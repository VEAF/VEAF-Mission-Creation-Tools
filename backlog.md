# Backlog — VEAF Mission Creation Tools v6

## Legend

- **Type**: `feat` / `fix` / `chore`
- **Status**: `⬜` to do · `🔄` in progress · `✅` done

> Completed lots are moved to [backlog-archive.md](backlog-archive.md).

---

## Summary

| Lot | Status |
|-----|--------|
| Lot FOOTHOLD-V6 — adopt the third-party Foothold mission onto the v6 toolchain: generic `convert-other` + declarative profiles, native-trigger strip, partial config-override with lexical validation, `--update` refresh, Modern/Cold-War multi-variant build (pilot: Caucasus) | ⬜ |
| Lot CLEANUP-LUPA — remove the dead `lupa` dependency (no longer imported since SECREV-001; still bundled by RC-002) | ⬜ |
| Lot FIX-AIRWAVES-GENERATOR — `lua_config_generator.py` emits `AirWaveZone` setters that don't exist in `veafAirWaves.lua` (`setMessageWaveDeployed`, `setMessageEndZone`, `setMessageEndAll`, `setMinimum/MaximumSecondsBetweenWaves`) → generated AirWaves configs crash at mission start | ✅ |
| Lot CLI-TUI-BRIDGE — any command invoked without its required options (or with `--tui`) drops into the TUI, skipping the steps already given on the CLI; supersedes prepare's interim `no_args_is_help` | ✅ |
| Lot DCS-UPDATE-VERIFY — post-DCS-update verification campaign: re-check every DCS-derived datum + runtime behaviour after a DCS World update | ✅ |
| Lot FIX-SPAWNABLES-CATEGORY — default `spawnables.yaml` files all 50 CAP plane templates under the DCS `helicopter` category (`airplanes:` empty); a stale extraction artifact (current `extract` categorizes correctly) | ✅ |
| Lot LUA-I18N-CAS — localize the `_cas` user-facing messages (missed by LUA-I18N-004): the post-spawn confirmation and the F10 target report are hardcoded English | ✅ |
| Lot LUA-I18N-WEATHER — localize the `veafWeatherData` report (`toString`/`toStringExtended`/`toStringAtis`); keep standardized aeronautical abbreviations as-is | ✅ |
| Lot LUA-I18N-SWEEP — audit + localize all remaining non-community VEAF on-screen messages (move/namedpoints/spawn/qra/airwaves/sanctuary/groundai/mg/combatzone/combatmission/carrier/transport) | ✅ |
| Lot FIX-CONVERT-V5-COMMENTS — `convert-v5` extracts commented-out (`--[[ ]]`) ASSETS/QRA definitions as active and counts comment-only module bodies as enabled → phantom config + spurious "group absent" build warnings | ✅ |
| Lot FIX-VERSION-PY-EOL — generated `_version.py` written in text mode → CRLF on Windows vs `eol=lf` → working tree always dirty; force LF | ✅ |
| Lot LUACHECK-CI — `luacheck` already wired in CI + `.luacheckrc`; only the stale `CLAUDE.md` "not installed, skip it" note needed fixing | ✅ |
| Lot LUA-COVERAGE — Lua coverage gate (`--cov-fail-under` + CI job, floor 67) + backfill `veafUnits` 20→93% | ✅ |
| Lot QUALITY-GATE-FINISH — erode the remaining mypy `ignore_errors` workers + final coverage ratchet | ✅ |
| Lot VALIDATE — `veaf-tools validate`: lint `mission.yaml` + `.miz` before build | ✅ |
| Lot SCAFFOLD — module-preset templates for `prepare` (minimal/standard/full/custom) generating mission.yaml; no separate `new` command | ✅ |
| Lot BUILD-PUBLISH-LOCAL — `veaf-build` local publish mode: deploy `published/` + the two `.exe` into a user-given VEAF mission source folder instead of GitHub | ✅ |
| Lot CUSTOM-SCRIPTS-TRIGGERS — custom_scripts not loaded in static (trig/trigrules divergence); unify trigger emission + fix (Flogas feedback) | ✅ |
| Lot TUM-AUTOINIT — call TheUniversalMission init automatically when TUM is selected | ✅ |
| Lot INVESTIGATE-REDFOR-ZONES — understand the "Coalition red has no territory zones / controls no airfields" runtime error | ✅ |
| Lot FIX-CONVERT-V5-INVALID-YAML — convert-v5 produces a mission.yaml that fails YAML parsing (indentation error) | ✅ |
| Lot DOC-REVIEW — full documentation proofreading pass (FR/EN), accuracy vs current behaviour after the 6.5.0 changes | ✅ |
| Phase 0b — GitHub cleanup | ✅ |
| Lot CI-NODE24 — Migrate GitHub Actions off deprecated Node.js 20 | ✅ |
| Lot TUI-YAML-DEFAULTS — TUI defaults aware of an existing mission.yaml | ✅ |
| Lot 5 — RELEASE | ⬜ |
| Lot FIX-BUILD-BARE-NAME-PATH — `build` with a bare mission name produces a relative output path, breaking the weather step | ✅ |
| Lot FIX-EXTRACT-COMMUNITY-DICT — `extract` crashes with KeyError on community script dicts | ✅ |
| Lot FIX-I18N-CONVERT-V5 — Hardcoded English messages in convert-v5 | ✅ |
| Lot FIX-LUADATA-NIL — pure-Python luadata parser (SECREV-001) rejects `nil` values, breaking convert-v5 on `country = nil` | ✅ |
| Lot CONVERT-CUSTOM-LOADER-HINT — guide users whose v5 mission uses a custom Lua script-loader toward the v6 `custom_scripts:` mechanism (resolves IMC2-003) | ✅ |
| Lot PERF-LUADATA-PARSER — pure-Python luadata parser (SECREV-001) slow on large missions; build 5-10× slower | ✅ |
| Lot FIX-DYNLOAD-PUBLISHED — dynamic loading broken from `published/` (loaded individual scripts absent from the bundle); split DEV/PROD + generate veafDynamicConfig.lua | ✅ |
| Lot FIX-EMPTY-COALITION-COUNTRY — `build` crashes (`'dict' object has no attribute 'append'`) on a mission with an empty coalition side | ✅ |
| Lot FIX-WAYPOINTS-INJECT-PRESERVE-ROUTE — waypoint injection wiped a flight's takeoff → "flight delayed to start"; append-not-replace. Also reverts FIX-DEFAULTS-AIRCRAFT-ROSTER (misdiagnosis) | ✅ |
| Lot FIX-DEFAULT-MODULES-ACTIVE — default mission.yaml was all-commented → no VEAF menu on a fresh build; ship an active baseline modules block | ✅ |
| Lot FIX-DEFAULTS-MODULES — MiST mandatory (always injected), remove WEATHERMARK from default, TUM kept | ✅ |
| Lot FIX-BUILD-COPY-DEFAULTS — default mission.yaml copied AFTER config read → no veaf-config.lua when mission.yaml absent; copy it before reading | ✅ |
| Lot WEATHERMARK-REMOVE — retire the WeatherMark community script everywhere (file, registry, validator, docs) | ✅ |
| Lot TUM-INIT — generate `TUM.initialize()` in veaf-config.lua so `TUM: true` actually starts TheUniversalMission | ✅ |
| Lot BUILD-AUTOVERSION — `veaf-build` auto-computes the release build number from the project base version vs the published.zip version | ✅ |
| Lot PREREL-BUGS — pre-release code review findings (briefing over-capture, exit codes, i18n, error handling) | ✅ |
| Lot SECREV — full-repo code review findings (lupa RCE, helicopter extraction data loss, zip hardening, Lua nil-derefs) | ✅ |
| Lot TODO0609-MODULES-UNIFY — single `modules:` block as source of truth (QRA + community config nested), CTLD/CSAR extracted from v5 | ✅ |
| Lot TODO0609-CONVERT-FIDELITY — convert-v5 report fidelity: comment full migrated blocks, emit commented-out v5 elements, silenceAtc key | ✅ |
| Lot TODO0609-ERA-AUTODETECT — auto-detect mission era (incl. WW2) from `.miz` content, manual override wins | ✅ |
| Lot TODO0609-SPAWN-EXTERNALIZE — externalize spawn group / veafUnits definitions from Lua to YAML (spike ✅ + impl) | ✅ |
| Lot TODO0609-DYNLOAD-CLARIFY — clarify `veafDynamicConfig.lua` vs `VeafDynamicLoader.lua`, find obsolete one (spike) | ✅ |
| Lot TODO0609-PRESETS-FIDELITY — iso-functional v5 presets conversion (fix) + presets data-structure/defaults analysis (spike) | ✅ |
| Lot TODO0609-TRIGGERS-VERIFY — verify DCS trigger migration behaviour for custom scripts (with Flogas) | 🟡 |
| Lot BUILD-COMMUNITY-SOUNDS — build packages CTLD/CSAR sound assets into l10n/DEFAULT when enabled (files-only) | 🟡 |
| Lot TODO0609-TUI-FOLDER-HINT — clarify the TUI mission-folder default (`.`) | ✅ |
| Lot TODO0609-AIRCRAFT-INJECT — split aircraft-group injection into spawnable-aircraft vs dynamic-slot-template steps, flag/prefix sort | ✅ |
| Lot TODO0609-DEFAULTS-AUDIT — audit `defaults/mission-folder` for genuinely-unused leftover files | ✅ |
| Lot UXPILOT-FEEDBACK — surface command errors to pilots (global pcall guard + unified feedback + unknown-parameter hints) | ✅ |
| Lot LUA-I18N — localize in-game VEAF messages (Lua runtime i18n; FR default + EN) | ✅ |
| Lot QUALITY-GATE — erode mypy `ignore_errors` and ratchet the coverage gate, one worker per lot | ✅ |
| Lot SPAWN-REFACTOR — characterize `veafSpawnParser` with tests, then de-duplicate the spawn subsystem | ✅ |
| Lot DYNSLOT-WAREHOUSE — wire injected `dynSpawnTemplate` groups into the `.miz` `warehouses` so DCS offers them as Dynamic Slots | ✅ |
| Lot DOC-CHATBOT — free RAG documentation chatbot (Cloudflare Worker + in-Worker cosine + Gemini) embedded in the MkDocs site | ✅ |
| Lot CHATBOT-CLI — expose the doc chatbot as a `veaf-tools` CLI command (`ask`) + TUI entry, reusing the CI-built index | ✅ |
| Lot CHATBOT-CLI-WORKER — `ask` proxies the project Worker (no user API key); supersedes the direct-key path | ✅ |
| Lot IMC-FEEDBACK-2 — second-round IMC-Day user feedback (tested with 6.4.0 on 2026-06-10) | ✅ |
| Lot DCSDATA — fix the missing-country-id ME crash, generate DCS country data from the datamine, consolidate all DCS-data generators under one `veaf-build` command with freshness guards, and lift the 2-ground-group mission requirement | ✅ |
| Lot FIX-WAYPOINTS-ETA-LOCKED — injected flight plans leave every waypoint unlocked, so DCS rejects the save ("Route has no waypoints with locked time!") | ✅ |
| Lot FIX-PRESETS-RADIO-COMPAT — `inject-presets` overwrites an aircraft's radio with a preset whose frequencies are wholly out of range (e.g. UHF on a Yak-52), so DCS rejects the save ("Invalid frequency 243 MHz") | ✅ |
| Lot TEST-PHASE-6.4.x — fixes from the manual v6.4.x test campaign (dynamic loading, warehouse templates, radio presets, spawn UX, coalition refactor) | ✅ |

---

## Lot FOOTHOLD-V6 — adopt the third-party Foothold mission onto the v6 toolchain

**Goal**: Bring the existing Foothold build process (community mission by Lekaa: Moose + zone-commander engine + CTLD + Splash/AIEN/EWRS, per-map variants) onto the v6 toolchain — a **build-only** port (no gameplay/engine rework), turning the current Mission-Editor-and-disk dance into a reproducible "moulinette" any VEAF member can re-run several times a month against a fresh upstream `.miz`. Architecture: **generic code, author-specific knowledge as data** (see [ADR 0007](docs/adr/0007-third-party-mission-adoption.md)) and **untouched upstream config + partial override validated lexically** (see [ADR 0008](docs/adr/0008-foothold-config-override.md)). The hand-written `VEAF_common.lua` loader (loadfile-by-path, dynamic-only) disappears, replaced by declarative `mission.yaml` (VEAF `modules:` + ordered `custom_scripts:`); static mode becomes the primary deliverable (single `.miz`, no disk sync). Iso-functional: MiST = VEAF module; Moose / zoneCommander / **Foothold CTLD (Lekaa's)** / setup / Config / Splash / AIEN / EWRS = `custom_scripts:` (no VEAF CTLD in Foothold). **Pilot: Caucasus.** Quality ratchet applies: any worker substantially edited here (e.g. `mission_extractor`, `mission_builder`) must drop its mypy `ignore_errors` entry, and the coverage gate bumps.

**Branch**: `feat/foothold-v6` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| FOOTHOLD-V6-001 | `convert-other` command — generic third-party `.miz` adoption: extract, generically detect embedded `.lua` + native load triggers, scaffold `mission.yaml` (`custom_scripts:`, `strip_native_triggers:`, baseline VEAF `modules:`), emit a conversion report. Distinct from `convert-v5` (migrate VEAF) — adopts a non-VEAF mission. Includes TUI menu entry + missing-arg fallback (CLI-TUI-BRIDGE). Also added `MissionExtractorWorker(keep_community_scripts=True)` to preserve third-party copies of known community scripts (iso-functional). | `veaf_tools/commands/`, `mission_*/`, `test/python/` | feat | ✅ |
| FOOTHOLD-V6-002 | Conversion-profile system — declarative data profiles (bundled under `veaf_libs/data/convert-profiles/`, path-overridable) carrying enabled VEAF modules, incompatible modules, versioned-name normalisation, and a `config_override` scaffold + target. Load order is auto-detected by 001, so not in the profile. Ship the reference `foothold` profile; `convert-other --profile`; incompatibility check enforced in `validate` **and** the build. | `veaf_libs/conversion_profile.py`, `veaf_libs/data/convert-profiles/`, `mission_*/`, `veaf_libs/mission_validator.py`, `test/python/` | feat | ✅ |
| FOOTHOLD-V6-003 | `strip_native_triggers:` at build — remove native DCS load triggers by name/pattern, reusing the `clear_veaf_triggers` infra. Generic `custom_scripts:`-level option, no "foothold" in code. | `mission_builder/mission_builder_worker.py`, `test/python/` | feat | ⬜ |
| FOOTHOLD-V6-004 | Partial config-override — render `config_override:` (generic passthrough `lua-global = value`, nested paths) to a small Lua script loaded **between** upstream config and setup. **Lexical token validation** per path segment against the whole Foothold corpus (corpus β), **build-blocking error** on a not-found segment, pure-Python regex (no Lua execution / no lupa, per SECREV-001). | `lua_config_generator.py` or new lib, `config_migrator.py` helpers, `test/python/` | feat | ⬜ |
| FOOTHOLD-V6-005 | `--update` mode — re-import a fresh upstream `.miz`: refresh third-party scripts (fix the extract "keep-old-version" behaviour), normalise versioned names (stable `custom_scripts:` paths), preserve the tuned `mission.yaml`, report scripts added/removed upstream. | `mission_extractor/`, `mission_*/`, `test/python/` | feat | ⬜ |
| FOOTHOLD-V6-006 | Modern / Cold-War multi-variant build — a single mission folder yields **both** `.miz` at build time (variant = config only), via VMCT build profiles. | `mission_builder/`, `mission.yaml` profiles, `test/python/` | feat | ⬜ |
| FOOTHOLD-V6-007 | Caucasus pilot + process doc — integrate Caucasus end-to-end (mission folder committed in `VEAF-Foothold-Caucasus`), document the moulinette (init + `--update`) for a third party, validate iso-functionally in DCS. 🧑 **Gate (David)**: manual DCS test of both variants. | `VEAF-Foothold-Caucasus` repo, `doc/` | feat | ⬜ |

---

## Lot CLEANUP-LUPA — remove the dead `lupa` dependency

**Goal**: `lupa` (Lua runtime) is no longer imported anywhere in `src/python/` — SECREV-001 routed all `.miz`/Lua parsing through the pure-Python `luadata` state machine to remove the RCE, and RC-002 then (needlessly, in hindsight) made `lupa` a non-optional dependency + `hiddenimports` in the `.spec` to bundle it in the exe. It is now pure dead weight in the dependency tree and the binary. Remove it. (Surfaced while planning FOOTHOLD-V6: the config-validation design deliberately avoids reintroducing lupa.)

**Branch**: `chore/cleanup-lupa` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| CLEANUP-LUPA-001 | Drop `lupa` from `pyproject.toml` dependencies, from the `hiddenimports` in `veaf-tools.spec`, and the `lupa.*` mypy override; verify no `import lupa` remains and the exe still builds. | `pyproject.toml`, `veaf-tools.spec`, `test/python/` | chore | ⬜ |

---

## Lot FIX-AIRWAVES-GENERATOR — generated AirWaves configs call non-existent setters

**Goal**: `lua_config_generator._emit_airwave_zone` emitted an `AirWaveZone:new():…:start()` chain including setters absent from `src/scripts/veaf/veafAirWaves.lua` (`setMessageWaveDeployed`, `setMessageEndZone`, `setMessageEndAll`, `setMinimumSecondsBetweenWaves`, `setMaximumSecondsBetweenWaves`). In Lua a nil method call raises "attempt to call method '…' (a nil value)" → any mission whose `mission.yaml` configures an AirWaves zone crashed at mission start. Found during the DOC-REVIEW audit (out of doc scope).

**Branch**: `fix/airwaves-generator` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| FIX-AIRWAVES-GENERATOR-001 | Emit only real `AirWaveZone` methods: map `message_wave_deployed`→`setMessageDeploy`, `message_end_zone`→`setMessageWon`; collapse the inter-wave delay to a single `setDelayBetweenWaves` (prefer the configured min — no runtime random range); drop the unsupported `message_end_all` + max-delay bound. Add a test parsing `veafAirWaves.lua` for the real `AirWaveZone` methods that asserts every emitted method exists | `src/python/veaf-tools/veaf_libs/lua_config_generator.py`, `test/python/veaf_libs/test_lua_config_generator.py` | fix | ✅ |

**Done**: generator emits only verified `AirWaveZone` setters; 3 regression tests (`test_emit_airwave_zone_only_real_methods` parses the Lua and asserts no emitted method is non-existent; plus message-mapping and delay-collapse tests). The Lua's runtime model has no random min/max inter-wave delay and no "all zones cleared" message, so those config keys collapse/drop rather than crash. (A proper random-delay + cross-zone-message feature in `veafAirWaves.lua` would be a separate enhancement, not a bug fix.)

---

## Lot CLI-TUI-BRIDGE — fall back to the TUI for missing options

**Goal**: make the CLI and TUI two faces of the same flow. When a veaf-tools command is invoked **without the options it needs** (or with `--tui` on any command), drop into the TUI **at the right step**, pre-filling whatever was already given on the command line and only prompting for the rest, then run the command. Examples: `veaf-tools` → main menu; `veaf-tools prepare` → prepare's option prompts (template, path…); `veaf-tools prepare c:\tmp` → prepare's prompts **minus** the path (already supplied) → just asks the template. This supersedes prepare's interim `no_args_is_help` (bare `prepare` will enter the TUI prepare flow instead of printing help).

**Design notes / open questions (to settle when scoping)**:
- **Trigger**: `--tui` on any command (force), OR a "required" prompt for that command is missing from the CLI. Only commands that have a `CommandSpec` participate; others keep plain Typer behaviour.
- **"Provided vs default" detection**: Typer args carry defaults, so we can't natively tell "user typed it" from "default". Inspect `sys.argv` against the command's `CommandSpec.prompts` (map positional/flag tokens → `ArgPrompt.key`), in `main()` before `app()`.
- **Which prompts are "required"**: mark them on `ArgPrompt` (e.g. a `required`/`prompt_if_missing` flag) so optional flags (`--verbose`, `--force`) don't force the TUI; for `prepare`, template + folder qualify.
- **Reuse**: extend `run_wizard` to accept a target command + a set of pre-filled args and skip those prompts; `main()` routes to it.

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| CLI-TUI-BRIDGE-001 | `--tui` flag + missing-required detection routes any `CommandSpec` command into the TUI, pre-filling CLI-provided args and prompting the rest; replace prepare's `no_args_is_help`; tests; docs | `veaf_tools/app.py`, `veaf_libs/tui.py`, `veaf_tools/commands/`, `test/python/`, `doc/`, `CHANGELOG.md` | feat | ✅ |

**Done**: `maybe_bridge_to_tui()` + `_parse_provided()` added to `veaf_libs/tui.py`, called from `app.main()` before Typer dispatch; `ArgPrompt` gained `required` + `choices`; `run_wizard(preselected, provided)` skips the command-select step and any pre-filled prompt, and renders a `choices` select (used by `prepare`'s template). `prepare`'s `no_args_is_help` was **kept** as the non-TTY safety net (in a TTY the bridge rewrites argv first, so it never fires; outside a TTY a bare `prepare` still prints help rather than scaffolding the cwd). Tests in `test_tui.py` (`_parse_provided`, `maybe_bridge_to_tui`, bridge `run_wizard` paths); FR/EN docs in the mission-maker guide; coverage floor 68→69. **Review follow-up**: `GROUNDAI` now sits in `CASMISSION`'s tiers (`standard`/`full`) so the build no longer silently auto-enables an undeclared dependency. (An Escape-navigation attempt was reverted: making every prompt `mandatory=False` + binding a bare `escape` key broke the wizard on the Windows console — the first prompt skipped to `None`, so the bridge fell back to `no_args_is_help`. Escape navigation needs a terminal-tested reimplementation.)

---

## Lot DCS-UPDATE-VERIFY — post-DCS-update verification campaign

**Goal**: a DCS World update landed; re-verify the maximum of things the toolchain depends on — every DCS-derived datum **and** the in-game runtime behaviour — and journal each check (remark → analysis → fix) in `TEST-PLAN-DCS-UPDATE.md`. Key insight: almost all DCS data comes from the **Quaggles datamine** at a pinned `DATAMINE_REF` (not the local DCS install), so a DCS update does **not** auto-change our data — only a datamine bump does. Only **airdromes** (`airdromes.yaml`, from `Mods/terrains/<map>/Beacons.lua`) depend on the local install and are **not** CI-guarded. Single branch, single PR at the end if fixes are produced.

**Branch**: `feature/dcs-update-verify` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| DCS-VERIFY-D1 | Datamine drift check: pinned `DATAMINE_REF` vs upstream HEAD | `veaf_build/dcs_data/datamine.py` | chore | ✅ |
| DCS-VERIFY-D2 | Regenerate countries + units at the pinned ref, assert no drift from committed data | `veaf_libs/data/`, `src/scripts/veaf/dcsUnits.lua` | chore | ✅ |
| DCS-VERIFY-D3 | Regenerate airdromes from the updated local DCS install; verify dynamic-slot warehouse name→id wiring | `veaf_libs/data/airdromes.yaml` | chore | ✅ (+6 Syria airfields) |
| DCS-VERIFY-D4 | Regenerate radio specs + re-apply `dcs_rejects_on_load` overlays (only if datamine bumped) | `presets_injector/data/dcs-radio-specs.yaml` | chore | ⬜ (deferred) |
| DCS-VERIFY-D5 | Run all DCS-data tests | `test/python/veaf_build/`, `test/python/veaf_libs/` | test | ✅ |
| DCS-VERIFY-R3-BUG | Static bundle dropped `veafSpawnParser.lua` (spawn-refactor regression) → `_cas`/`_spawn` parsing broke in static (`convertLaserToFreq` nil). Added it to the bundle list; extracted `LUA_BUNDLE_SCRIPTS`/`LUA_BUNDLE_EXCLUDED`; manifest-completeness test | `veaf_build/worker.py`, `test/python/veaf_build/test_lua_bundle_manifest.py` | fix | ✅ |
| DCS-VERIFY-R3-MQ9 | v5→v6 regression: default `spawnables.yaml` dropped the `veafSpawn-MQ-9 - AFAC - JTAC - DRONE` template → `_cas` AFAC + `-afac` alias found no MQ-9. Restored it (extracted from the demo mission, under `airplanes`) | `src/defaults/mission-folder/src/spawnables.yaml` | fix | ✅ |
| DCS-VERIFY-R | In-game runtime checklist in the updated DCS (R0-R7): mission loads, scripts load static+dynamic, F10 menu, ME save round-trip, dynamic slots, presets/waypoints save, convert-v5/build read. All green; 2 bugs fixed in-lot (bundle, MQ-9), 3 findings spun off | `TEST-PLAN-DCS-UPDATE.md` | test | ✅ |

---

## Lot FIX-SPAWNABLES-CATEGORY — default spawnables mis-categorize planes as helicopters

**Goal**: the shipped default `src/defaults/mission-folder/src/spawnables.yaml` files all 50 fixed-wing CAP templates (F-15C, M-2000C, MiGs, …) under the **`helicopters:`** category (`airplanes:` was empty before the MQ-9 restore). The build injects them faithfully → in the `.miz` they land under the country's `helicopter` group table instead of `plane`. Confirmed in a built mission. The current `extract-aircraft-groups` tool categorizes correctly (it put the MQ-9 under `airplanes`), so this is a **stale extraction artifact** baked into the committed default, not a live tool bug. Found during DCS-UPDATE-VERIFY (R3-FINDING-2) and spun off. **TBD**: (1) confirm whether the wrong category actually breaks CAP spawning at runtime or veaf re-derives it from the unit type (sets priority); (2) regenerate / re-categorize the default set under `airplanes`; (3) check the source the default was generated from.

**Branch**: `fix/spawnables-category` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| SPAWNCAT-001 | Confirm runtime impact, then re-categorize the default CAP templates from `helicopters` to `airplanes` (regenerate via `extract` if that's the clean source); regression test asserting planes land under `airplanes` | `src/defaults/mission-folder/src/spawnables.yaml`, `test/python/` | fix | ✅ |

**Outcome**: confirmed **not cosmetic** — the CAP spawn path (`veafSpawnAircraft.lua` → `mist.teleportToPoint` clone → `mist.dynAdd`) never re-derives the category, so `coalition.addGroup` receives `Unit.Category.HELICOPTER` for fixed-wing units. Regenerating from the source mission was rejected (the extractor reflects the source `.miz` faithfully, so a mis-categorized source would reproduce the bug). Fixed with a category-aware migration keyed on the canonical `dcsUnits.yaml`: all 50 templates moved `helicopters:` → `airplanes:` (none was a real helicopter), 51 group bodies preserved byte-for-byte. New `test_spawnables_defaults_category.py` guards both the shipped data (both directions) and the injector bucket → DCS-table mapping.

---

## Lot LUA-I18N-CAS — localize `_cas` user-facing messages

**Goal**: LUA-I18N-004 routed most module messages through `veaf.t` but missed `veafCasMission`'s on-screen text, which stays English even when `veaf.config.language = "fr"`. Found during DCS-UPDATE-VERIFY (R3-FINDING-3). In scope: the short post-`_cas` spawn confirmation (`veafCasMission.lua:1103`, "TARGET: Group of N vehicles and M soldiers…") and any other short CAS feedback. The detailed F10 target report (LAT/LON, MGRS, bullseye, weather, ~1118-1151) is the "data report" category LUA-I18N-004 deliberately deferred — decide whether to include it. Add `veaf.t` keys with FR + EN catalog entries (`veafI18n.lua`) and Lua tests, following the LUA-I18N-004 pattern.

**Done**: decision was to localize **all** of `veafCasMission`'s own on-screen text (per user — "tous les messages VEAF localisés sauf modules communautaires comme CTLD"). 11 `cas.*` catalog keys added (FR + EN): spawn confirmation, full target report (target/AFAC/LAT-LON decimal & DMS/MGRS/from-bullseye value & line/weather header) and the `_cas` HELP text. The weather **body** stays English — it is `veafWeatherData.getWeatherString(...)`, a different module out of this lot's scope. Command tokens (`_cas`, `defense`, `size`, `armor`, `spacing`) kept literal in both languages. 9 new tests in `test/lua/test_veafI18n.lua` (17 total, all green).

**Branch**: `feature/lua-i18n-cas` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| LUA-I18N-CAS-001 | Route the short `_cas` feedback messages through `veaf.t` (FR + EN); decide on the detailed target report; Lua tests | `src/scripts/veaf/veafCasMission.lua`, `src/scripts/veaf/veafI18n.lua`, `test/lua/` | feat | ✅ |

---

## Lot LUA-I18N-WEATHER — localize the `veafWeatherData` report

**Goal**: follow-up to LUA-I18N-CAS. The weather report produced by `veafWeatherData` (`veafWeather.lua`, `toString` / `toStringExtended` / `toStringAtis` and their helpers) was left English, but per the project rule every VEAF on-screen message must be localized (only community modules like CTLD are exempt). It is shown after `_cas` (F10 target report), in `veafCombatZone`, and on the carrier weather menu. Route all user-facing descriptive words and labels through `veaf.t` with FR + EN catalog entries: wind `calm`, cloud densities (`No clouds`/`Scattered`/`Broken`/`Overcast`/`Few clouds`), visibility affects (`fog`/`haze`/`mist`/`dust`/`precipitations`), and the report/ATIS line labels (`Wind`/`Visibility`/`Clouds`/`Temperature`/`Dew point`/`Sunrise`/`Sunset`/`Time`/`Location`/`Altitude`, ATIS phraseology). **Decision (user)**: standardized aeronautical abbreviations stay as-is in both languages (`CAVOK`, `QNH`, `QFE`, `kts`, `m/s`, `NM`, `SM`, `ft`, `Hpa`, `inHg`, `mmHg`, `°M`/`°T`, `AGL`/`ASL`, `FL`, `LASTE`) — a FR pilot reads them unchanged. Logs stay English. Existing `test_veafWeather.lua` rendering tests assert the English words under the default FR config, so they must load `veafI18n.lua` and pin `language = "en"`; FR coverage is added at the catalog level in `test_veafI18n.lua`.

**Branch**: `feature/lua-i18n-weather` → PR → `develop-v6`

**Done**: 28 `weather.*` catalog keys added (FR + EN); all descriptive words/labels in `toStringWind`/`toStringVisibility`/`toStringClouds`/`toString`/`toStringExtended`/`toStringAtis` routed through `veaf.t`. Aeronautical abbreviations kept verbatim per the user decision. `test_veafWeather.lua` now loads `veafI18n.lua` and pins `language = "en"` (its assertions verify the English wording + format logic); 6 FR catalog tests added to `test_veafI18n.lua` (23 total). Full Lua suite green, stylua clean.

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| LUA-I18N-WEATHER-001 | Route the `veafWeatherData` report (toString/Extended/Atis + helpers) through `veaf.t` (FR + EN), keep aeronautical abbreviations; update `test_veafWeather.lua` (load i18n, pin en) and add FR catalog tests | `src/scripts/veaf/veafWeather.lua`, `src/scripts/veaf/veafI18n.lua`, `test/lua/` | feat | ✅ |

---

## Lot LUA-I18N-SWEEP — localize all remaining VEAF on-screen messages

**Goal**: complete the i18n migration started by LUA-I18N-004/CAS/WEATHER. Per the project rule, every VEAF on-screen message must be localized (only community modules like CTLD are exempt). An exhaustive parallel audit of all non-community `veaf*.lua` modules found ~100 player-facing strings (passed to `outText*` / `markTo*`) still hardcoded in English. Route them all through `veaf.t` with FR + EN catalog entries.

**Decisions**:

- **Brevity / aeronautical codes stay verbatim** in both languages (extends the WEATHER decision): TACAN, ICLS, LINK 4, ACLS, BRC, COMM, BRA, MERGED, CAVOK, QNH, QFE, kn, kts, NM, SM, MGRS, AM, SRS, etc.
- **F10 radio-menu labels are out of scope** — they double as `delCommand` identifiers, so localizing them would break command removal.
- **Mission-overridable default messages** (QRA, AirWaves, Sanctuary, GroundAI, MissileGuardian, the default CAP objective) now store i18n **keys** as their defaults and resolve them through `veaf.t` at send time: the default localizes, while a mission's custom override passes through unchanged (`veaf.t` returns an unknown key verbatim before formatting).
- Logs stay English; only on-screen text is localized.

**Branch**: `feature/lua-i18n-sweep` → PR → `develop-v6`

**Done**: ~95 catalog keys added (FR + EN) across `move.*`, `namedpoints.*`, `spawn.*`, `qra.*`, `airwaves.*`, `sanctuary.*`, `groundai.*`, `mg.*`, `report.*` (shared coord/count fragments), `combatzone.*`, `combatmission.*`, `carrier.*`, `transport.*`. 13 modules routed through `veaf.t`. Rendering tests in `test_veafCombatZone`/`test_veafCombatMission`/`test_veafCarrierOperations` now load `veafI18n.lua` and pin `language = "en"`; representative FR/EN tests added to `test_veafI18n.lua` (32 total). Full Lua suite green (34 suites), stylua clean, no duplicate catalog keys.

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| LUA-I18N-SWEEP-001 | Audit + route all remaining non-community VEAF on-screen messages through `veaf.t` (FR + EN); key-as-default pattern for overridable templates; keep brevity codes and radio-menu labels; update affected rendering tests + add FR catalog tests | `src/scripts/veaf/*.lua`, `src/scripts/veaf/veafI18n.lua`, `test/lua/` | feat | ✅ |

---

## Lot FIX-CONVERT-V5-COMMENTS — convert-v5 must ignore Lua comments

**Goal**: `convert-v5` analyses `missionConfig.lua` to detect active modules and extract ASSETS/QRA definitions, but it does **not** respect Lua comments. In the standard VEAF template, each module body is shipped inside a `--[[ … ]]` "uncomment to enable" block; convert-v5 (1) treats a module as active from the `if veafXxx then` guard even when its entire body is commented, and (2) regex-scans `name=…` definitions **inside** `--[[ ]]` blocks, emitting phantom ASSETS/QRA into `mission.yaml`. Found during DCS-UPDATE-VERIFY (R7-BUG) on the Training-Syrie mission: 14 commented-out assets + QRA were emitted as active, then flagged "absent from the mission" at build (the real groups have different names). High impact — most real v5 missions ship config commented. **Fix**: strip Lua line (`--`) and block (`--[[ ]]`) comments from `missionConfig.lua` before module-activation detection and asset/QRA extraction; a commented module body should not enable the module or contribute definitions. Regression test on a fixture with a fully-commented `veafAssets.Assets` block.

**Branch**: `fix/convert-v5-comments` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| CV5COM-001 | Strip Lua comments before convert-v5's module-activation + ASSETS/QRA extraction; commented bodies contribute nothing; regression tests | `mission_builder/config_migrator.py`, `test/python/mission_builder/test_convert_v5_commented_modules.py` | fix | ✅ |

---

## Lot FIX-VERSION-PY-EOL — generated `_version.py` always shows as modified

**Goal**: `veaf-build` writes `veaf_tools/_version.py` (and restores its stub) in Python text mode, so on Windows `\n` is translated to `\r\n`. The git-tracked stub is normalized to LF (`.gitattributes` `eol=lf`), so every build left the working tree permanently "modified" with a CRLF-only, content-less diff — recurring friction. **Done**: `_write_version_py` / `_restore_version_py` now pass `newline="\n"`; the same latent bug in `radio_specs_updater` (tracked `dcs-radio-specs.yaml` / `.md`) was fixed too, matching the `dcs_data` generators that already force LF. Regression tests assert LF output. Working tree `_version.py` renormalized.

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| FIX-VERSION-PY-EOL-001 | Force LF (`newline="\n"`) in `_write_version_py`/`_restore_version_py` and the radio-specs writers; renormalize the tracked stub; LF regression tests | `veaf_build/worker.py`, `veaf_build/radio_specs_updater.py`, `test/python/veaf_build/test_version_py_eol.py` | fix | ✅ |

---

## Lot LUACHECK-CI — add luacheck to the CI Lua quality gate

**Goal**: ensure real static analysis on the Lua side (a blind spot in the quality ratchet — only `stylua --check` formatting was assumed to run). **Investigation revealed the work was already done**: `.github/workflows/lua-ci.yml` has a dedicated `Luacheck` job (installs Lua 5.1 + luacheck via LuaRocks, runs `luacheck src/scripts/veaf/ --config .luacheckrc`), a committed `.luacheckrc` exists, and the job passes green (0 warnings, e.g. PR #473). The Lua quality gate already enforces luacheck.

**Done**: the only real gap was a **stale, self-contradictory `CLAUDE.md`** — its Lua section (§7) tells you to run luacheck, but the workflow step (§8.6) said "`luacheck` is not installed, skip it". Fixed §8.6 to list `luacheck --config .luacheckrc src/scripts/veaf/` alongside `stylua`, note both are CI-enforced (`lua-ci.yml`), and that a missing local install (Windows) means relying on the CI check — never treating the gate as skippable. `copilot-instructions.md` was already correct. No CI/`.luacheckrc`/script changes needed; luacheck stays not-installed locally on Windows (CI is the source of truth).

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| LUACHECK-CI-001 | Investigate the existing CI Luacheck job; fix the stale `CLAUDE.md` §8.6 "not installed, skip it" note to reflect that luacheck is a CI-enforced Lua gate | `CLAUDE.md` | chore | ✅ |

---

## Lot LUA-COVERAGE — Lua test-coverage objective for runtime modules

**Goal**: the Lua runtime modules (`veafCasMission`, `veafCombatZone`, `veafQraManager`, …) are far less tested than the Python side. Establish a measurable Lua coverage objective (luacov via `test-lua`), set a baseline gate, and add tests for the least-covered critical modules. Secures the campaign/persistence work that will touch these modules.

**Done (wave 1)**: luacov + the report table were already wired in `test-lua`; the gaps were the **gate** and **CI**. Added `--cov-fail-under FLOAT` to `test-lua` (`_display_coverage_report` now returns the total %; exit 1 when below the floor) with Python tests, and a new `lua-coverage` CI job in `lua-ci.yml` (lua5.1 + luacov via LuaRocks → `poetry run test-lua --cov-fail-under 67`). Baseline measured 68.50 %; floor set to **67** (ratchet — only ever goes up). **Backfill**: `veafUnits` 20.36 % → **93.10 %** (33 tests targeting `placeGroup`/`processGroup`/`findGroup`/`countInfantryAndVehicles`/`removePathfindingFixUnit`/log/trace/initialize), lifting the total to **69.73 %**. A file-scoped `math.random` mock reproduces DCS' permissive reversed-interval behaviour (`placeGroup` L609-610 passes m>n on normal groups; DCS tolerates it, stock Lua 5.1 raises "interval is empty") — a DCS-environment mock, not a bug. **Wave 2+ (separate lots)**: the ~50 % cluster (`Sanctuary`, `CombatMission`, `Skynet*`, `Weather`, `MissileGuardian`, `CombatZone`, `CasMission`, …), raising the floor each pass.

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| LUA-COVERAGE-001 | Coverage gate (`--cov-fail-under` in `test-lua` + `lua-coverage` CI job, floor 67) + `veafUnits` backfill 20→93 % (total 68.50→69.73 %) | `veaf_build/lua_tests.py`, `.github/workflows/lua-ci.yml`, `test/lua/test_veafUnits.lua`, `test/python/veaf_build/test_lua_coverage_gate.py`, `CLAUDE.md` | test | ✅ |

> **Wave 2+ tracked separately**: raising the ~50 %-covered cluster (`Sanctuary`, `CombatMission`, `Skynet*`, `Weather`, `MissileGuardian`, `CombatZone`, `CasMission`, …) and ratcheting the floor up will be its own lot when scheduled.

---

## Lot QUALITY-GATE-FINISH — erode the remaining mypy exclusions

**Goal**: finish the Quality Ratchet Policy (`CLAUDE.md` §3) — the `QUALITY-GATE` lot is closed but, per policy, the dedicated lot still mops up whatever workers no other lot reopened. Remaining `ignore_errors = true` application workers (the bundled `luadata` library stays excluded as third-party): `mission_converter.mission_converter_worker`, `mission_extractor.mission_extractor_worker`, `waypoints_injector.waypoints_manager`, `weather_injector.utils.lua_converter`, `weather_injector.weather.dcs_weather_converter`, `weather_injector.weather_injector_worker`. Drop each entry, fix the surfaced type errors, and do a final `--cov-fail-under` ratchet.

**Done**: removed all six application-worker entries from the mypy `ignore_errors` override (only `luadata*` third-party stays). Measuring first showed just **7 errors across 2 files** — the other four workers were error-free. Fixes were behaviour-preserving: `config: dict[str, Any]` annotation in `weather_injector/utils/lua_converter.py` (4 errors), and in `mission_extractor_worker.py` renamed a shadowed loop variable + dropped two redundant `: Path` re-annotations (3 errors). The whole `src/python/veaf-tools` tree now passes `mypy` with no per-module opt-outs. No `--cov-fail-under` bump: the lot adds no tests and coverage is unchanged (68.37 % vs gate 67, gap < 2). No behaviour change → existing tests cover (suite green).

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| QUALITY-GATE-FINISH-001 | Remove the remaining application-worker entries from the mypy `ignore_errors` list and fix the surfaced errors (keep `luadata*` third-party exclusion); bump `--cov-fail-under` per policy | `pyproject.toml`, `src/python/veaf-tools/**`, `test/python/` | chore | ✅ |

---

## Lot VALIDATE — `veaf-tools validate` (pre-build linter)

**Goal**: add a `veaf-tools validate` command that lints a mission folder **before** build, turning late DCS-side crashes into clear design-time errors. Checks to cover: incoherent/unknown `modules:` entries, `custom_scripts` files that do not exist, presets/waypoints that match no aircraft in the `.miz`, missing REDFOR/BLUFOR territory zones when `TUM: true`, and structural validity of `mission.yaml` (overlaps the active `FIX-CONVERT-V5-INVALID-YAML` lot — share the YAML-parse check). Exit non-zero on error, with localized messages.

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| VALIDATE-001 | `validate` command + `veaf_libs.mission_validator`: mission.yaml syntax/semantics (reusing non-aborting `check_yaml_syntax`/`collect_module_issues`), custom_scripts existence, declared-group presence, presets/waypoints aircraft presence (coarse), TUM zone prerequisite; `--strict`; localized FR/EN output; tests; maker-guide docs | `veaf_tools/commands/validate.py`, `veaf_libs/mission_validator.py`, `veaf_libs/yaml_validator.py`, `test/python/`, `doc/`, `CHANGELOG.md` | feat | ✅ |

---

## Lot SCAFFOLD — `veaf-tools new` (mission folder scaffolding)

**Goal**: lower the entry cost for new mission makers by scaffolding a `mission.yaml` from a chosen module preset. **Decision (with David)**: `prepare` already copies the default scaffold, so **do not add a separate `new` command** — extend `prepare` with `--template`. Templates are coverage tiers, not per-module: `minimal` (infra + RADIO/SPAWN/SHORTCUTS/INTERPRETER), `standard` (everyday set), `full` (everything; config-heavy modules as commented examples), `custom` (interactive module pick). In all cases the generated `mission.yaml` reflects the chosen modules + adapted config defaults. `SECURITY` off by default everywhere; `GROUNDAI` excluded (unfinished); `TUM` only in `full`, commented + warning.

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| SCAFFOLD-001 | Data-driven module catalog + `mission.yaml` generator (`veaf_libs/mission_template.py`, single source of truth); `prepare --template minimal\|standard\|full\|custom` + `--list-templates` + interactive `custom` + next-steps guidance; localized FR/EN; tests (generator + CLI); maker-guide docs | `veaf_libs/mission_template.py`, `veaf_tools/commands/prepare.py`, locales, `test/python/`, `doc/`, `CHANGELOG.md` | feat | ✅ |

---

## Lot BUILD-PUBLISH-LOCAL — local publish mode for `veaf-build`

**Goal**: add a **local publish** mode to `veaf-build` that, instead of uploading the release to GitHub (rarely done now that the CI handles publishing), deploys the build output directly into a **user-provided target directory** — a VEAF mission source folder. The mode copies the contents of the `published/` folder plus the two compiled executables (`veaf-tools.exe`, `veaf-tools-updater.exe`) into that folder, so a mission maker gets the latest tooling + scripts locally without going through GitHub / the updater.

**Decisions (settled)**: dedicated subcommand `publish-local <dir>` (not a flag on the GitHub-specific `publish`); deploy from the canonical `published.zip`; the goal is to reproduce the **end state of the updater run in a mission folder** — extract `published.zip` into `<dir>/published/` and **move** both `.exe` to the folder root; overwrite in place (the `.exe` are overwritten); the `.exe` are carried by `published.zip` so no cross-platform special-casing.

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| BUILD-PUBLISH-LOCAL-001 | `veaf-build publish-local <dir>` (+ `deploy_published_locally` worker): extract `published.zip` into `<dir>/published/`, move `veaf-tools.exe`/`veaf-tools-updater.exe` to root — reproduces the updater's end state, no GitHub. Tests, `TOOLS_REFERENCE` (FR/EN), CHANGELOG, version bump. | `veaf_build/cli.py`, `veaf_build/worker.py`, `test/python/veaf_build/`, `doc/`, `CHANGELOG.md` | feat | ✅ |

---

## Lot TUM-AUTOINIT — auto-init TheUniversalMission when selected

**Goal**: when `TUM` is selected in `mission.yaml` `modules:`, `TUM.initialize()` (TheUniversalMission) must be called automatically — **but TUM must never be enabled by default** (vanilla mission or `convert-v5`), because it aborts at start-up without BLUFOR/REDFOR territory zones.

**Done**: made TUM **opt-in** across the build. New `get_optin_community_script_ids()` (`mission_constants.py`) returns `{"tum"}`; the builder enablement (`enabled_community_script_ids`, `_active_community_scripts`, `_community_enabled`), the generator `_community_enabled` (None-branch), and `convert-v5` output now treat opt-in ids as OFF unless an explicit `<ID>: true` is set — while opt-out scripts (ctld, csar, …) keep their active-by-default behaviour. When `TUM: true`, the generator still emits `if TUM then TUM.initialize() end`. `convert-v5` emits `TUM: false` even when the TUM file is detected. Tests added (builder opt-in parsing, generator default-off, convert-v5 emit). Doc: `MISSION_YAML_REFERENCE` (FR/EN) opt-in note, default `mission.yaml` comment, CHANGELOG.

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| TUM-AUTOINIT-001 | Make TUM opt-in (off by default everywhere) and auto-init `TUM.initialize()` only when `TUM: true` | `mission_tools/mission_constants.py`, `mission_builder/mission_builder_worker.py`, `mission_builder/v5_converter.py`, `veaf_libs/lua_config_generator.py`, `test/python/` | fix | ✅ |

---

## Lot INVESTIGATE-REDFOR-ZONES — "red has no territory zones / no airfields" error

**Goal**: understand the runtime error `ERROR: Coalition red has no territory zones and/or controls no airfields. Please add zone with a name starting with REDFOR in the mission editor and make sure at least one contains an airbase.` Identify which module/script raises it (REDFOR/BLUEFOR zone convention — likely a community or campaign-style script), when it fires, whether it is expected/benign or a VEAF-side issue, and what (if anything) the build or docs should do about it.

**Branch**: `feature/INVESTIGATE-REDFOR-ZONES` → PR → `develop-v6`

**Findings (spike DONE)**:

- **Source**: the message is emitted by **TheUniversalMission (TUM)**, the bundled third-party community script `src/scripts/community/TheUniversalMission.lua` (akaAgar's *the-universal-mission-for-dcs-world*) — **not** by any VEAF script. Exact site: `TUM.territories.onStartUp()` (`TheUniversalMission.lua:29272-29279`), reached via `TUM.initialize()` → local `startUpMission()` (`:30300`).
- **When it fires**: only when **TUM is initialized**. Since lot **TUM-INIT**, the VEAF build emits `if TUM then TUM.initialize() end` in the generated `veaf-config.lua` whenever the mission selects `TUM: true` in `mission.yaml` `modules:`. So selecting the `TUM` community module on a mission that was not authored as a TUM mission triggers this code path at mission start.
- **Why**: TUM is a self-contained PvE mission generator that takes over the whole map. At startup `TUM.territories.onStartUp()` (1) **strips every airbase to NEUTRAL** (`autoCapture(false)` + `setCoalition(NEUTRAL)`), then (2) scans all trigger zones: a zone whose name starts (case-insensitively) with `BLUFOR`/`REDFOR` is assigned to BLUE/RED and **captures every airbase geographically inside it** for that side (`addZoneToCoalition`, `:29138`). It then requires **each** side to own **≥1 territory zone AND ≥1 airbase**; otherwise it logs this ERROR and aborts (`return false` → `trigger.action.outText("A critical error has happened, cannot start the mission.")`). The `for side=1,2` loop maps `side 1 → RED → "REDFOR"`, `side 2 → BLUE → "BLUFOR"`.
- **Verdict — expected, not a VEAF bug**: this is a **mission-design prerequisite of the TUM framework**, working as TUM intends. It is benign in the sense that nothing in the VEAF tooling is broken; the mission maker enabled a self-contained mission framework without giving it the map it needs. (TUM has further prerequisites that abort `startUpMission()` the same way: Player/Client slots present, exactly one `Player` slot in single-player, ≥1 generic mission zone, and `autoexec.cfg` enabling `net.dostring_in`.)
- **Resolution (no code change)**: build behaviour is correct — we must not silently swallow a community script's startup contract. Documented the prerequisite in `MISSION_YAML_REFERENCE` (FR/EN) next to the `TUM` module id: enable `TUM` only for a TUM-style mission, and set up the ME with a `BLUFOR…` zone and a `REDFOR…` zone, each containing at least one airbase (plus ≥1 other mission zone). No build-time guard added: VEAF cannot know whether the maker intends a TUM mission, and TUM's own error message already tells the pilot exactly what to add.

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| INVESTIGATE-REDFOR-ZONES-001 | Trace the source of the REDFOR-zones error; document the cause and the required mission-editor setup. **Done**: traced to TUM's `TUM.territories.onStartUp()` (community script); it is an expected TUM mission-design prerequisite (BLUFOR/REDFOR territory zones each owning an airbase), not a VEAF bug. Documented the prerequisite under the `TUM` module id in `MISSION_YAML_REFERENCE` (FR/EN). No code/guard change. | `doc/MISSION_YAML_REFERENCE.md`, `doc/MISSION_YAML_REFERENCE.en.md` | spike | ✅ |

---

## Lot FIX-CONVERT-V5-INVALID-YAML — convert-v5 emits unparseable mission.yaml

**Goal**: on a freshly converted v5 mission, `build` aborts with a YAML syntax error in the generated `mission.yaml` (observed: "Erreur de syntaxe dans mission.yaml, ligne 308, colonne 7 — l'erreur débute vers la ligne 212, colonne 7", indentation). `convert-v5` is producing structurally invalid YAML. Reproduce, find the offending emitted block (indentation/escaping around the reported lines), fix the generator, and add a regression test that the generated mission.yaml always parses.

**Done**: reproduced on the reporting mission (`Training-Syrie`) — exact error `expected <block end>, but found '?'` at line 212/308. Root cause in `_emit_qra_definitions`: a QRA defined with `start = false` in v5 emitted `start: false` via the `converter.yaml.qra.start_comment` translation, which **hard-coded a 6-space indent** — placing the field at the `definitions:` sequence level instead of inside its `- name:` item (8-space `field` indent like every other QRA field). The misaligned key broke the block sequence. Fixed by emitting `f"{field}start: false  {t(...)}"` and reducing the FR/EN translation to the comment only. (No twin bug — `start_comment` was the only i18n value hard-coding YAML indentation.) Verified: `Training-Syrie` now parses; 4 regression tests assert the QRA block parses (single/multiple disabled defs, correct indent, `start:true` emits nothing).

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| FIX-CONVERT-V5-INVALID-YAML-001 | Reproduce + fix the indentation bug in the convert-v5 mission.yaml emitter (QRA `start: false` indent via hard-coded i18n); regression tests that output parses | `mission_builder/v5_converter.py`, `veaf_libs/locales/{en,fr}.json`, `test/python/mission_builder/test_convert_v5_qra_yaml.py` | fix | ✅ |

---

## Lot CUSTOM-SCRIPTS-TRIGGERS — unify trigger emission, fix custom_scripts loading

**Goal**: Flogas reported that in 6.5.0 a script declared in `custom_scripts` is parsed (its missing-file warning clears) but is **not loaded in static missions** — no load trigger carries it. Root cause: every VEAF load trigger is emitted twice with duplicated, divergent logic — `insert_veaf_triggers()` (`trig` table) and `insert_veaf_trigrules()` (`trigrules` table, the one DCS executes). The static mission trigger #6 diverged: the `trigrules` form hardcodes only veaf-config + mission-script (omits custom_scripts — the bug), while the `trig` form wrongly includes `veafDynamicConfig.lua` (latent error in static). This duplication also caused C6 (double-spawn).

**Approach** (validated with David): emit BOTH forms from a single per-trigger spec (`VeafTriggerSpec` + `LuaAction`/`FileAction`) so they can never diverge; the static mission trigger and the dynamic `veafDynamicConfig.lua` both use the one ordered list `_ordered_mission_script_names()` (veaf-config → mission-script → custom_scripts; excludes veafDynamicConfig.lua, in one place). Keep `custom_scripts` API as a single `generate_load_trigger` flag (repaired to apply in both modes); mode-specific script sets ("dynamic-only" debug scripts) are handled via build **profiles** (documented). `mission-script.lua` stays auto-loaded first. Annexes: spawn-data trigger kept separate + documented; CTLD-beacons legacy v5 trigger deferred (needs Flogas's exact CTLD/CSAR config). Plan: `C:\Users\David\.claude\plans\federated-churning-pascal.md`.

**Branch**: `feature/custom-scripts-triggers` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| CUSTOM-SCRIPTS-TRIGGERS-001 | Unify trig/trigrules emission from a single spec (`_build_veaf_trigger_specs` + `_emit_trig_action_string`/`_emit_trigrule_actions`); fix static #6 to load custom_scripts and exclude veafDynamicConfig.lua; repair `generate_load_trigger`; tests (custom_scripts in both static trigrule & veafDynamicConfig; trig↔trigrules parity; golden #1-5). **Note**: `meters`/`zone` dropped (not preserved) per David's in-session decision, superseding the plan's "preserve" note. | `mission_builder/mission_builder_worker.py`, `test/python/mission_builder/` | fix | ✅ |
| CUSTOM-SCRIPTS-TRIGGERS-002 | Docs: custom_scripts semantics (loads in both modes, order veaf-config → mission-script → custom_scripts) + how to get "dynamic-only"/"static-only" via build profiles (deep-merge replaces lists → repeat base scripts) | `doc/MISSION_YAML_REFERENCE.*` (FR/EN), `CHANGELOG.md` | chore | ✅ |

---

## Lot DOC-REVIEW — full documentation proofreading pass

**Goal**: a complete, exhaustive read-through of the whole `doc/` tree (every FR `.md` + EN `.en.md` pair) — not just the targeted, changelog-driven audit done for the 6.5.0 release. Check: technical accuracy vs current behaviour, FR/EN parity (no desync), broken/relative links, stale filenames and command names, terminology consistency, examples that still run, and overall readability for mission makers / pilots / script developers. The 6.5.0 release touched many areas (YAML data + datamine, Dynamic Slots, in-game i18n, doc chatbot, aircraft-template split, dynamic loading, defaults), so the docs deserve a full pass.

**Branch**: `feature/DOC-REVIEW` → PR → `develop-v6`

> **Chatbot index during this lot**: this pass touches most of `doc/**` at once, which would trigger the `Rebuild docs chatbot index` CI workflow on every push and risk exhausting the Gemini free-tier embeddings quota (1000/day). **Before starting**, disable that workflow (GitHub → Actions → "Rebuild docs chatbot index" → ⋯ → Disable workflow). **When done**, re-enable it and refresh the index once — either trigger the workflow manually (`workflow_dispatch`), or run it locally with `poetry run reindex-docs` (incremental, on-disk cache; a single full pass ≈ 500-700 embeds stays under the cap).

**Audit outcome (2026-06-17)**: a 9-way parallel audit of all 38 FR/EN pairs surfaced ~55 distinct issues, split into two risk classes → delivered in **two phases / two PRs**:

- **Phase 1 (clear-cut)** — broken links (ADRs live in `docs/adr/`, outside `docs_dir: doc` → use absolute GitHub URLs; over-deep `../` links; wrong-language anchors), stale version/count strings (TESTING 31→34 suites + 2 undocumented CI jobs, PIPELINE 85→87 aircraft + step numbering, LUA_API versions/IDs), stale module IDs/keys (`SHCUT`→`SHORTCUTS`, blank→`SANCTUARY`, `enable`→`enabled`, `lua_modules`→`modules`), wrong commands/config (`convert-mission` removed, `weather-inject`→`inject-weather` + real `versions.yaml` schema, Skynet `external_modules:`→`modules.SKYNET`, QRA top-level `qra:`→`modules.QRA`, `_cas`/`_spawn` param fixes), FR/EN parity gaps. **Done in this lot.**
- **Phase 2 (fabricated Lua APIs)** — ~14 script-doc sections document builder/class APIs that don't exist in the v6.5.25 Lua and need verified rewrites against source (`VeafGrassRunway`, most `VeafCombatZone`/`VeafCombatOperation` methods, `veafCarrierOperations.addCarrier`, `veafCasMission.start`, `VeafSanctuary`→`VeafSanctuaryZone`, `VeafMissileGuardian` (stub), `veafMove.moveTanker/changeTanker` signatures + `_teleport`/`SpawnKeyphrase`, `veafNamedPoints.addNamedPoint`, `veafTransportMission` builder+menu, `veaf.weatherReport`, `veafAirWaves` method names + `:initialize()`→`:start()`, `veafAssets` `groupName`/`carrier`, `veafRadio` example callbacks, the whole `TOOLS_REFERENCE` publishing half, the `LUA_API_REFERENCE` `veafWeather`/`veafTime`/`dcsUnits`/`dcsDataExport` function entries, and the pilot carrier/CAS menu labels). Tracked as **DOC-REVIEW-003**.

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| DOC-REVIEW-001 | Phase 1 — clear-cut fixes across `doc/` (FR/EN): broken links, stale versions/counts/IDs/keys, wrong commands/config, FR/EN parity | `doc/**` | chore | ✅ |
| DOC-REVIEW-002 | Chatbot index: no manual disable needed — the `Rebuild docs chatbot index` workflow only triggers on `push` to `develop-v6` (+ `workflow_dispatch`), so feature-branch pushes never fire it; the single merge to `develop-v6` reindexes exactly once (= the "refresh once after") | `.github/workflows/docs-chatbot-index.yml` | chore | ✅ |
| DOC-REVIEW-003 | Phase 2 — rewrote every fabricated Lua-API doc section against the real source (source-grounded, each symbol grep-verified) | `doc/mission-maker/scripts/**`, `doc/LUA_API_REFERENCE.*`, `doc/TOOLS_REFERENCE.*`, `doc/mission-maker/GUIDE.*`, `doc/pilot/GUIDE.*` | chore | ✅ |

**Phase 2 done (2026-06-17)**: replaced fabricated builder/class APIs with the real ones across the script docs — `VeafGrassRunway` (→ editor-naming workflow), `VeafCombatZone`/`VeafCombatZoneElement`/`VeafCombatOperation` methods, `veafCarrierOperations.addCarrier` (→ auto-discovery), `veafCasMission.start` (→ `initialize`), `VeafSanctuary` (→ `VeafSanctuaryZone` + `addZone`), `VeafMissileGuardian` (→ `VeafMG_Guardian`), `veafMove.moveTanker/changeTanker` signatures + `_teleport`/`SpawnKeyphrase`, `veafNamedPoints.addNamedPoint` (→ `addPoint`/`addDataToPoint`), `veafTransportMission` builder+menu (→ marker `_transport`), `veaf.weatherReport` (→ `veafWeatherData.getWeatherString`), `veafAirWaves` method names + `:initialize()`→`:start()`, `veafAssets` `groupName`/`carrier`/`information`, `veafRadio` example callbacks, and the whole `TOOLS_REFERENCE` publishing half (→ `veaf-build publish`). Deeper symbol-verification also caught and fixed items the original audit missed: `veafAirbases.setAirbaseData` (→ query API) + the `LUA_API_REFERENCE` `Airbase`/`Runway`/`veafCombatMission` `mission:`/`objective:` sections (→ real `veafAirbase`/`VeafCombatMission`/`VeafCombatMissionObjective`), and the `mission-maker/GUIDE` QRA/CombatZone/AirWaves/`VeafAlias` examples. An automated doc→source symbol checker now reports every VEAF method/function call in `doc/**` resolving to a real definition.

> **Pilot screenshots — resolved with placeholders (2026-06-17)**: `doc/pilot/GUIDE.{md,en.md}` referenced 7 screenshots under `../assets/img/pilot/*.png` that don't exist yet. Each image reference is now a *"📷 Capture à venir / Screenshot coming soon"* note (caption preserved) so nothing renders broken; David can drop in the real images later by restoring the `![…](…png)` syntax. (`fix/pilot-screenshots`)

---

## Lot TEST-PHASE-6.4.x — manual test-campaign fixes

**Goal**: during the manual v6.4.x test campaign (a v6-built mission tested in DCS in **dynamic** mode, plus design-time checks of `convert-v5`, the CLI/TUI and `veaf-build`), every plan section (build, runtime, convert-v5, CLI/TUI, DCS data, security/perf) was exercised. Most items already worked; the issues below were found and fixed. Each is journaled (remark → analysis → fix) in the temporary `TEST-PLAN-VEAF-6.4.x.md`. Single branch, single PR.

**Branch**: `fix/tests` → [PR #468](https://github.com/VEAF/VEAF-Mission-Creation-Tools/pull/468) → `develop-v6` (squash `d62e0c23`)

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| C1 | Split spawn/QRA proxies (`veafSpawn.lua`/`veafQraManager.lua`) resolve their dir under DCS dynamic `loadfile` (chunk source without `@`), fixing the `no file 'veafSpawnCore.lua'` + `veafRemote`/`veafUnits` nil cascade | `src/scripts/veaf/veafSpawn.lua`, `veafQraManager.lua` | fix | ✅ |
| C2 | Generated `veafDynamicConfig.lua` no longer lists itself → no infinite reload at mission start in dynamic mode | `mission_builder/mission_builder_worker.py`, `test/python/` | fix | ✅ |
| C3 | `SHORTCUTS` enabled by default in the shipped `mission.yaml` (built-in aliases work out of the box) | `src/defaults/mission-folder/mission.yaml` | feat | ✅ |
| C4 | `CASMISSION` + `TRANSPORTMISSION` enabled by default (marker-driven, no config) | `src/defaults/mission-folder/mission.yaml` | feat | ✅ |
| C5 | Config generator maps each module id to its real table name (`<table>.Id`) not the filename → `veafSpawn.initialize()`/`veafQraManager.initialize()` actually run in dynamic mode (`_spawn` handler registered) | `veaf_libs/lua_config_generator.py`, `test/python/` | fix | ✅ |
| C6 | Dynamic mission trigrule loaded `veaf-config.lua` twice (explicit + via `veafDynamicConfig.lua`) → modules initialized twice → markers fired twice; removed the redundant explicit load | `mission_builder/mission_builder_worker.py`, `test/python/` | fix | ✅ |
| C7 | `_spawn unit` success message + JTAC variant routed through `veaf.t` (FR+EN) | `src/scripts/veaf/veafSpawnAircraft.lua`, `veafI18n.lua` | fix | ✅ |
| C8 | Warehouse dynamic-slot aircraft nested by category (`aircrafts.helicopters`/`.planes`) so `linkDynTempl` binds; classified via the DCS units DB | `warehouses_injector/warehouses_injector_worker.py`, `test/python/` | fix | ✅ |
| C9 | Presets: drop per-aircraft out-of-range channels so the mission still saves + add the missing MiG-15bis radio spec (extends FIX-PRESETS-RADIO-COMPAT) | `presets_injector/`, `presets_injector/data/dcs-radio-specs.yaml`, `test/python/` | fix | ✅ |
| C10 | Coalition refactor: `veaf.getOppositeCoalition` (spawn side) + `veaf.getRequesterCoalition` (feedback audience) replace the scattered inversion; the unknown-parameter hint reaches the requester | `src/scripts/veaf/veaf.lua`, `veafSpawnCore.lua`, `veafCasMission.lua`, `veafShortcuts.lua`, `veafMarkers.lua`, `test/lua/` | fix | ✅ |
| C11 | An unknown spawn parameter aborts the command (message, no spawn) instead of spawning anyway | `src/scripts/veaf/veafSpawnCore.lua`, `test/lua/` | fix | ✅ |

---

## Lot FIX-PRESETS-RADIO-COMPAT — skip presets incompatible with an aircraft's radio

**Goal**: `inject-presets` replaces each player aircraft's `Radio` with the preset resolved from `presets.yaml` (often via an `all` fallback). When that preset's frequencies are entirely out of range for the aircraft's radio hardware — e.g. a UHF/VHF/FM preset resolved for a **Yak-52**, whose only radio is the sub-MHz ARK-15M (0.1–1.795 MHz) — the build overwrites the correct radio with frequencies the DCS Mission Editor refuses to save (*"Invalid frequency 243 MHz"*). The radio-frequency validator already knows each aircraft's valid ranges (`dcs-radio-specs.yaml`). Fix: before injecting, if **every** preset frequency is invalid for a *known* aircraft, skip the injection and keep the original radio (a clear warning is logged). Partially-valid presets are still injected (the existing per-frequency warning/report covers their stray channels). Verified end-to-end on the demo mission: the Yak-52 keeps its ARK-15M radio (no 243); only the Yak-52 is skipped, F18/A-10/M-2000C presets are untouched. Note: 243 MHz is the legitimate UHF guard channel and is valid for the F18/A-10 — the bug was applying it to the Yak-52, not the channel itself.

**Branch**: `fix/PRESETS-RADIO-COMPAT` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| FIX-PRESETS-RADIO-001 | `_preset_radio_compatible` in the presets worker: skip injection when every preset frequency is out of range for a known aircraft (keep its radio); inject otherwise. Regression tests (Yak-52 skipped, FA-18C kept, unknown aircraft kept, partially-valid kept). | `presets_injector/presets_injector_worker.py`, `test/python/` | fix | ✅ |

## Lot FIX-WAYPOINTS-ETA-LOCKED — injected routes have no locked-ETA waypoint

**Goal**: `inject-waypoints` rebuilds each player aircraft's route from a `waypoints.yaml` flight plan (matched by aircraft type, so a catch-all plan rewrites every human slot). Every `WaypointDefinition` defaults to `ETA_locked=false` and the flight plans don't set it, so the injected route has **no** waypoint with a locked ETA — DCS then refuses to save the mission with *"Route has no waypoints with locked time!"* on every affected group. Fix: after building the route, if no waypoint is locked, lock the first one (its departure), as DCS itself does. Verified end-to-end on the demo mission (F18 Stennis 1, Yak 52 CTLD, test-QRA, … all now have a locked first waypoint). Note: the separate *"Invalid frequency 243 MHz"* error is user config — `presets.yaml` presets the UHF guard frequency (243.0), which DCS reserves; not a build bug.

**Branch**: `fix/WAYPOINTS-ETA-LOCKED` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| FIX-WP-ETA-001 | In `_inject_waypoints_into_group`, lock the first waypoint when the flight plan locked none, so DCS accepts the route. Respect an explicit lock on any waypoint. Regression tests. | `waypoints_injector/waypoints_injector_worker.py`, `test/python/` | fix | ✅ |

## Lot DCSDATA — DCS country data pipeline, missing-id crash fix, and generator consolidation

**Goal**: `inject-aircrafts` crashes DCS at mission load (`me_mission.lua:512`, `fixCountriesNames` → `attempt to index field '?' (a nil value)`) when a `mission.yaml` injects aircraft into a country (e.g. `France`) that has no ground unit in the source `.miz`. Root cause: `AircraftGroupsInjectorWorker._ensure_country` only recovers a country's DCS numeric `id` by looking it up in another coalition already present in the mission (commit `bc37be3`, partial); a country absent everywhere is created **without `id`**, which DCS dereferences as nil on load. This lot makes country-id resolution systematic (mission → generated DCS table → hard error), generates the name→id table from the `Quaggles/dcs-lua-datamine` repo (each `_G/db/Countries/*.lua` carries `Name` + `WorldID`, CJTF/UN included — no DCS install needed), consolidates the scattered DCS-data generators (`dcsDataExport.lua`, `dcs_units_parser.py`, `radio_specs_updater.py`) under a single `veaf-build update-dcs-data` command with a pinned upstream + freshness guards (per-PR consistency + scheduled drift watcher), and finally lifts the documented "≥1 blue + ≥1 red ground group" base-mission requirement once a spike confirms a synthetic unit-less country satisfies the injectors and survives a DCS save.

**Branch**: `feature/DCSDATA` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| DCSDATA-001 | Make `_get_or_create_country` resolve the DCS `id` systematically: reuse an id already present in the mission, else look it up in the generated country table, else raise a clear build error (never emit a country without `id`). Regression test: inject an aircraft into a country absent from the whole mission, assert the created country carries the correct DCS id. Verified on the real demo mission (France now `id: 5`; mission loads in the ME — the remaining save-time route/radio validation errors are unrelated). | `aircrafts_injector/aircrafts_injector_worker.py`, `veaf_libs/dcs_countries.py`, `test/python/` | fix | ✅ |
| DCSDATA-002 | Country-table provider: generate `name → WorldID` (+ `ShortName`/`InternationalName` for robust matching) from `Quaggles/dcs-lua-datamine` `_G/db/Countries/*.lua`; commit the artifact; parser + unit tests. CJTF Blue/Red and UN Peacekeepers covered with no special-casing. | `veaf_build/dcs_data/`, `veaf_libs/data/dcs-countries.yaml`, `test/python/` | feat | ✅ |
| DCSDATA-003 | Consolidate datamine-sourced DCS-data generators under a `dcs_data` module with shared pinned clone; expose one `veaf-build update-dcs-data [--countries] [--radio] [--all]` command. **Radio is a hybrid artifact** (generated base + manual `dcs_rejects_on_load` overlays + bilingual doc): `--all` regenerates only `countries` (pure) and skips radio with a warning; `--radio` regenerates but warns that manual overlays must be re-applied. `units` stays separate (in-DCS export, not datamine). `update-radio-specs` alias kept. | `veaf_build/dcs_data/`, `veaf_build/cli.py`, `veaf_build/radio_specs_updater.py`, `test/python/` | feat | ✅ |
| DCSDATA-004 | Pin the upstream datamine ref (`DATAMINE_REF`) in `dcs_data.datamine` and stamp the provenance ref into each generated artifact's header — fixes the non-reproducible `master`/`--depth=1` clone; `radio_specs_updater` now uses the shared pinned clone. | `veaf_build/`, generated artifacts | chore | ✅ |
| DCSDATA-005 | Per-PR consistency guard: CI re-runs the **countries** generator against the pinned ref and `git diff --exit-code`, failing when the committed `dcs-countries.yaml` is stale or hand-edited. **Scope note**: only pure artifacts (countries) can use a regenerate-equality guard — radio has manual overlays, so it is excluded. Workflow `dcs-data-consistency.yml`; generation forces LF for cross-platform determinism. | `.github/workflows/` | chore | ✅ |
| DCSDATA-006 | Scheduled drift watcher (weekly cron): compare upstream `HEAD` to the pinned ref; when upstream moved, open a PR that bumps the pin + regenerates the pure artifact, for human review (the PR body lists the manual radio/units follow-up). Workflow `dcs-data-drift.yml`. | `.github/workflows/` | chore | ✅ |
| DCSDATA-007 | Spike (DONE — **NO-GO**): tested in the DCS ME whether a build-synthesized **unit-less** country survives. It does **not** — DCS purges any country with zero units on save (Mission A: an added unit-less country vanished; Mission B: a coalition whose only country was unit-less ended up empty). So a synthetic unit-less country cannot lift the 2-ground-group requirement. The only way to make DCS register a country is a **real** unit. Evidence: `tmp/dcsdata-007-spike/`. **Decision**: lift the constraint by injecting a minimal **real** hidden placeholder unit (see DCSDATA-007b). | — | spike | ✅ |
| DCSDATA-007b | Lift the 2-ground-group requirement: the build (`ensure_coalitions_populated`, hooked after `read_mission`) injects a single **hidden** real placeholder ground group into any empty blue/red coalition, on the coalition bullseye, under a roster-valid template country (USA 2 / Russia 0), keeping a valid locked-ETA route. Validated in the DCS ME: the placeholder **survives** load→save and stays hidden (preview `tmp/dcsdata-007-spike/dcsdata-007b-…-SAVED.miz`). Committed template `mission_builder/data/placeholder_groups.json` (real groups, ids/name/pos overridden at injection); also fixed PyInstaller bundling of `dcs-countries.yaml` + the template, and aligned both loaders on the `sys._MEIPASS` pattern. GUIDE FR/EN updated. | `mission_builder/coalition_placeholder.py`, `mission_builder/data/`, `veaf_build/worker.py`, `doc/mission-maker/GUIDE.*.md`, `test/python/` | feat | ✅ |
| DCSDATA-008 | Move the DCS **units** database onto the datamine, retiring the in-DCS export as the source of `dcsUnits.lua` (the export stays for airbases/weapons). **Done with a cleaner design than the original "re-emit the exact schema" plan** (David): two-stage pipeline `datamine → dcsUnits.yaml (canonical, committed) → dcsUnits.lua (rendered, committed)`. The runtime schema is **simplified** — keyed by DCS type, single `kind` (`air`/`naval`/`infantry`/`vehicle`/`static`) instead of four booleans — and `veafUnits` updated (fast keyed `findDcsUnit`, `processUnit` maps `kind`). `kind` derived from `attribute` flags; `NAVAL_STATICS` + `CARRIED_UNITS` (Container_20/40ft) curated for what the datamine lacks. Validated vs the old 833-unit file: 0 kind regressions. `--units` wired into `update-dcs-data` (pure, CI-guarded: consistency + drift); `dcs_units_parser` reads the YAML; `dcsUnits.lua` excluded from stylua (generated). Python + Lua tests; FR/EN docs. | `veaf_build/dcs_data/{units,units_lua}.py`, `src/scripts/veaf/{dcsUnits.lua,veafUnits.lua}`, `veaf_libs/{data/dcsUnits.yaml,dcs_units_parser.py}`, `.github/workflows/`, `doc/developer/dcs-data.*`, `test/` | feat | ✅ |

---

## Lot DOC-CHATBOT — free RAG documentation chatbot embedded in the MkDocs site

**Goal**: Add a free, bilingual (FR/EN) chatbot that guides users from within the VEAF v6 documentation site (MkDocs Material → GitHub Pages), modeled on the Solde chatbot but re-shaped for a static/public site. A Cloudflare Worker (free tier) holds the Gemini API key, enforces an Origin allow-list + per-IP rate-limit (KV), and answers via **RAG**: it embeds the question (`gemini-embedding-001`, 768d), retrieves the most relevant doc passages from a Cloudflare Vectorize index (filtered by language), and streams a grounded answer from `gemini-2.5-flash-lite`. RAG was adopted after a live test proved full-document injection (~100k tokens/request) hits the Gemini free-tier tokens-per-minute ceiling at ~2 questions/minute; context caching was ruled out (cached tokens still count against TPM and it requires billing). Implementation lives under `poc/doc-chatbot/` (Worker + index build script) and `doc/assets/chatbot/` (widget); deployed and validated live at `https://veaf-docs-chatbot.veaf.workers.dev`.

**Branch**: `claude/cranky-heyrovsky-e6f193` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| DOC-CHATBOT-001 | Cloudflare Worker RAG proxy: Origin allow-list (anti-CSRF), per-IP KV rate-limit, query embedding → in-Worker cosine ranking over a KV-stored vector index (lang-scoped) → Gemini SSE streaming. No paid vector DB. | `poc/doc-chatbot/worker/src/index.js`, `poc/doc-chatbot/worker/wrangler.toml` | feat | ✅ |
| DOC-CHATBOT-002 | Index build script: walk `doc/`, chunk markdown (greedy merge, oversized-paragraph safe), embed in throttled batches, emit per-language binary Float32 blobs + text bulk files for KV. Unit tests for the chunker + Worker helpers. | `poc/doc-chatbot/worker/scripts/build-index.mjs`, `poc/doc-chatbot/worker/test/unit.test.mjs` | feat | ✅ |
| DOC-CHATBOT-003 | MkDocs widget: vanilla-JS resizable sidebar (Solde-style), language auto-detection, SSE consume, sanitized DOM rendering (DOMPurify, no innerHTML), lazy CDN load; environment-aware endpoint config; wired via `mkdocs.yml`. | `doc/assets/chatbot/*.js`, `doc/assets/chatbot/*.css`, `mkdocs.yml` | feat | ✅ |
| DOC-CHATBOT-004 | CI workflow to rebuild the index and upload it to KV whenever docs change (keeps answers fresh). | `.github/workflows/docs-chatbot-index.yml` | feat | ✅ |
| DOC-CHATBOT-005 | Productionization prerequisites. **Done**: (1) repo secrets `GEMINI_API_KEY` / `CLOUDFLARE_API_TOKEN` (KV edit) / `CLOUDFLARE_ACCOUNT_ID` set by David; (2) the widget already ships to the versioned (mike) docs — it is wired in `mkdocs.yml` (`extra_javascript`/`extra_css`) and `docs.yml` deploys via `mike deploy`, which builds with that config, so every version includes it (no extra work); (3) a Gemini **429** now maps to the localized "too many requests" message instead of the generic "unavailable", on both the generation and embedding paths (`upstreamErrorMessage`). | `poc/doc-chatbot/worker/src/index.js`, `poc/doc-chatbot/worker/test/unit.test.mjs` | feat | ✅ |

---

## Lot CHATBOT-CLI — doc chatbot as a `veaf-tools` CLI command + TUI entry

**Goal**: Bring the documentation chatbot (ask a question about the VEAF docs, get a grounded AI answer) to the design-time tooling — a `veaf-tools ask` CLI command (one-shot + interactive REPL with session history) and a TUI menu entry — **reusing the same RAG index built by the docs CI** (single source of truth). The index (`vec-{lang}.bin` + `txt-{lang}.json` from `poc/doc-chatbot/worker/scripts/build-index.mjs`) is published as a public artifact; the Python tool downloads + caches it, then only embeds the question and generates the answer with the *user's own* `GEMINI_API_KEY`. No local re-embedding, no Cloudflare credentials, no extra runtime dependency (`requests` + pure-Python cosine). Approach decided over full-injection (wastes the user's quota at ~100k tokens/question) and over calling the deployed Worker (Origin allow-list 403 + burns the project's quota). Idiomatic to veaf-tools: Typer command in `commands/`, `BaseWorker` pattern, InquirerPy TUI, config via env var / `~/veafmct.yaml`, `veaf_libs.logger`, i18n `t()`, tests in `test/python/`.

**Branch**: `feature/chatbot-cli` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| CHATBOT-CLI-001 | Publish the embeddings index as a public artifact in the docs CI. **Done**: `docs-chatbot-index.yml` now also uploads `vec/txt-{lang}` to a rolling `doc-index` GitHub Release (in addition to the KV upload), so non-Cloudflare clients can fetch it over plain HTTPS. | `.github/workflows/docs-chatbot-index.yml` | feat | ✅ |
| CHATBOT-CLI-002 | `index_store`: download the published `vec-{lang}.bin` + `txt-{lang}.json`, cache under `~/.veaf/doc-index/` with an ETag check, expose load helpers (Float32 vectors + texts); fall back to the cache when offline. | `doc_chatbot/index_store.py`, `test/python/doc_chatbot/test_index_store.py` | feat | ✅ |
| CHATBOT-CLI-003 | `DocChatWorker` (`BaseWorker`): embed the question (`gemini-embedding-001`, 768d, user key) → cosine top-K over the cached index → stream a grounded answer from `gemini-2.5-flash-lite` (SSE via `requests`). Resolve the key from `GEMINI_API_KEY` env or `~/veafmct.yaml`; clear localized error if missing. | `doc_chatbot/doc_chat_worker.py`, `test/python/doc_chatbot/test_doc_chat_worker.py` | feat | ✅ |
| CHATBOT-CLI-004 | `ask` CLI command: one-shot (`veaf-tools ask "…"`) + interactive REPL (session history, `quit`); language from the global `--lang`; rendered via Rich `console`. | `veaf_tools/commands/ask.py`, `veaf_tools/commands/__init__.py`, `veaf_libs/locales/{en,fr}.json` | feat | ✅ |
| CHATBOT-CLI-005 | TUI entry « Ask the documentation » (runs `veaf-tools ask` → its REPL, reusing `DocChatWorker`). | `veaf_libs/tui.py`, `veaf_libs/locales/{en,fr}.json` | feat | ✅ |
| CHATBOT-CLI-006 | Docs (`doc/TOOLS_REFERENCE*.md` + TUI mention), `CHANGELOG`, version bump, and bump the coverage gate (66→67) per the ratchet policy. | `doc/TOOLS_REFERENCE.md`, `doc/TOOLS_REFERENCE.en.md`, `CHANGELOG.md`, `pyproject.toml` | feat | ✅ |

> **Superseded by `CHATBOT-CLI-WORKER`.** David's review: mission makers are not technical enough to obtain a Gemini key, so the CLI must work **with no key by default**. The original "download the index + embed/generate with the user's own key" design (001–003) was reworked to proxy the existing Cloudflare Worker (which already holds the project key server-side). The direct-key path was removed.

---

## Lot CHATBOT-CLI-WORKER — `ask` proxies the Worker (no user key)

**Goal**: Make `veaf-tools ask` work out of the box with **no API key**. A project key cannot be shipped in the distributed tool (it would be scraped and the quota/key abused), so the default routes through the project's Cloudflare Worker — which owns the Gemini key server-side, runs the RAG and streams the answer, exactly like the website chatbot. Supersedes CHATBOT-CLI-001/002/003 (the direct-key + local-index path was removed). David's decisions: **Worker only** (no user-key path) and the CLI authenticates with a **dedicated header** (not by loosening the browser Origin allow-list).

**Branch**: `feat/chatbot-cli-worker` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| CHATBOT-CLI-WORKER-001 | Worker: accept non-browser CLI requests via an `X-VEAF-Client: cli` header (`isAllowedClient`), keeping the browser Origin allow-list and the per-IP rate limit. Unit-tested. | `poc/doc-chatbot/worker/src/index.js`, `poc/doc-chatbot/worker/test/unit.test.mjs` | feat | ✅ |
| CHATBOT-CLI-WORKER-002 | Replace the direct-key client with `WorkerChatWorker` (POST `/chat` + `X-VEAF-Client` header, stream the SSE answer); rewire `ask`; remove `index_store`/`doc_chat_worker` and the key handling; revert the GitHub-Release index publish (no longer needed). Docs FR/EN (no key), CHANGELOG, version bump, locales, tests. | `doc_chatbot/worker_client.py`, `veaf_tools/commands/ask.py`, `.github/workflows/docs-chatbot-index.yml`, `doc/TOOLS_REFERENCE*.md`, `test/python/doc_chatbot/test_worker_client.py` | feat | ✅ |

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

## Lot FIX-LUADATA-NIL — pure-Python luadata parser rejects `nil` values

**Goal**: SECREV-001 replaced the lua-executing `luadata.unserialize` with a pure-Python state machine that never handled `nil` as a value. Real v5 configs write `key = nil` everywhere (notably `country = nil` and commented-out `["waypoints"]` blocks), so `convert-v5` failed to parse the `settings` table of `waypointsSettings.lua` (and any table with a `nil` value) — logged as `Unserialize luadata failed … unexpected character`, silently dropping that table's data. Discovered during IMC-Day 6.4.0 testing while reproducing IMC2-003.

**Branch**: `fix/luadata-nil-values` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| FIX-LUADATA-NIL-001 | Handle Lua `nil` as a value in the pure-Python unserializer: a `key = nil` entry is dropped (Lua semantics — the entry does not exist), matching the former lua-execution behaviour. No code execution reintroduced. Regression tests for named/bracketed `nil`, `nil` before a table key, and sibling preservation. | `luadata/serializer/unserialize.py`, `test/python/security/test_luadata_nil.py` | fix | ✅ |

---

## Lot CONVERT-CUSTOM-LOADER-HINT — guide custom Lua loaders to v6 `custom_scripts:`

**Goal**: IMC-Day testing (Flogas) showed a v5 mission whose own `src/scripts/VeafDynamicLoader.lua` is a *mission-scripts loader* (its own ordered `scriptsToLoad`: Moose, FgTools, FgWeather, FgCsg2, missionConfig, FgMission). `convert-v5` does not (and should not) parse arbitrary custom loaders, so those scripts were never registered as `custom_scripts:` → no load trigger → the runtime F10 menu was missing (the real **IMC2-003** root cause). Per David: do **not** build a brittle parser for one specific loader shape; instead detect generically that an undeclared `.lua` *loads other scripts* and point the user at the v6 `custom_scripts:` mechanism. Also resolves the misleading "unexpected lua file" advice for the v5 `VeafDynamicLoader.lua` (name-collides with the v6 framework loader — see ADR 0004).

**Branch**: `feat/custom-loader-hint` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| CUSTOM-LOADER-HINT-001 | When the build finds an undeclared `src/scripts/*.lua` whose content loads other scripts (heuristic on `loadfile`/`dofile`/`require`/`a_do_script_file`/`do_script_file`), emit an explanatory warning pointing to the v6 `custom_scripts:` section (instead of the generic "declare it" advice). Generic, no parsing of the loaded list. Replaces the IMC2-003 auto-migration idea (deemed too brittle for rare advanced cases). | `mission_builder/mission_builder_worker.py`, locales, `test/python/` | feat | ✅ |

---

## Lot PERF-LUADATA-PARSER — speed up the pure-Python Lua parser on large missions

**Goal**: SECREV-001 replaced the lua-executing parser with a pure-Python state machine to remove RCE. On large missions (Flogas, 8.9 MB `.miz`) the build became 5-10× slower — `read_miz` ≈ 0.86 s, dominated by the parser. Profiling showed two hotspots: `node_entries_append` re-sorted + rescanned the whole entry list on **every** append (`O(n²·log n)` per table), and the main loop walked the input one byte at a time (`sbins[pos:pos+1]` slice + whitespace test per char). Recover speed without reintroducing code execution.

**Branch**: `perf/luadata-parser` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| PERF-LUADATA-PARSER-001 | (a) Stop sorting/rescanning on every append — keep entries in append order, track array length incrementally via an int-key set, sort once lazily in `node_to_table` (`O(n²·log n)` → `O(n)`). (b) Skip insignificant whitespace runs at C speed (`re.search`) in states where whitespace only advances the cursor. `read_miz` 0.86 s → 0.33 s (~2.6×). Output identical (array/sparse-key ordering, whitespace-insensitivity, string whitespace preserved — guarded by tests). | `luadata/serializer/unserialize.py`, `test/python/security/test_luadata_parser_perf.py` | perf | ✅ |

---

## Lot FIX-DYNLOAD-PUBLISHED — make dynamic loading work in DEV and PROD

**Goal**: Dynamic loading was broken from a `published/` install (Flogas): the build always emitted the DEV framework loader (`VeafDynamicLoader.lua`, which `loadfile`s the **individual** `veaf/*.lua`), but `published.zip` ships only the concatenated **bundle** `veaf/veaf-scripts.lua` — so the individual files were absent → runtime "no file" error. Also, the mission maker's `custom_scripts` were never loaded dynamically (the hand-maintained `veafDynamicConfig.lua` only listed `mission-script.lua`). Per David: support two scenarios — **DEV** (load individual scripts from a repo checkout, `scripts_path`) and **PROD** (load the bundle from `scripts_path`, default `./published`) — and in both, load the mission maker's custom scripts dynamically.

**Branch**: `feat/dynload-prod` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| DYNLOAD-PROD-001 | Framework loader depends on mode: DEV (`dev_mode: true`) → `VeafDynamicLoader.lua` (individual scripts from the repo); PROD → bundle `veaf/veaf-scripts.lua` from `scripts_path` (default `published/`, already in `published.zip` — no packaging change). Applied to both the trigger and trigrule forms. | `mission_builder/mission_builder_worker.py`, `test/python/` | feat | ✅ |
| DYNLOAD-PROD-002 | Generate `src/scripts/veafDynamicConfig.lua` from the mission script list (`mission-script.lua` + `custom_scripts`, same order as the static triggers) so dynamic mode loads the mission maker's custom scripts too. File becomes generated (documented "do not edit"). | `mission_builder/mission_builder_worker.py`, `src/defaults/mission-folder/src/scripts/veafDynamicConfig.lua`, locales, `test/python/` | feat | ✅ |
| DYNLOAD-PROD-003 | Build-time validation: if dynamic loading is on and the framework loader is missing under `scripts_path` (DEV: `VeafDynamicLoader.lua`; PROD: `veaf/veaf-scripts.lua`), fail with a clear localized error instead of shipping a `.miz` that breaks at runtime. Document DEV/PROD in `MISSION_YAML_REFERENCE*`. | `mission_builder/mission_builder_worker.py`, locales, `doc/`, `test/python/` | feat | ✅ |

---

## Lot FIX-EMPTY-COALITION-COUNTRY — build crash on an empty coalition side

**Goal**: `veaf-tools build` crashed with `AttributeError: 'dict' object has no attribute 'append'` (`coalition_placeholder._find_or_add_country`) on a minimal mission where one side is empty. An empty DCS `country = {}` Lua table deserializes to a dict (not a list) under `all_is_dict`, so `setdefault("country", [])` returned the existing dict and `.append` failed. Reproduced with a single-A-10C Caucasus mission (blue populated, red/neutrals empty).

**Branch**: `fix/empty-coalition-country` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| FIX-EMPTY-COALITION-COUNTRY-001 | Coerce a coalition's `country` to a list (handling the empty-`{}` dict case, keeping any values) before appending the placeholder country. Regression test with `country: {}`. | `mission_builder/coalition_placeholder.py`, `test/python/mission_builder/test_coalition_placeholder.py` | fix | ✅ |

---

## Lot FIX-WAYPOINTS-INJECT-PRESERVE-ROUTE — waypoint injection wipes the takeoff

**Goal**: Taking a player slot in a built mission showed the DCS native message **"YOUR FLIGHT IS DELAYED TO START, PLEASE WAIT"** and the slot could not be taken. Root cause: the waypoints injector rebuilt each matched group's route from scratch with **only** the injected waypoints, wiping the original `TakeOffParking` point — the default `waypoints.yaml` example matches `all_blue_planes`, so a human A-10C2 lost its parking departure and got an airborne first waypoint (ETA in the future) → DCS delays the flight. Per David: injection must **append** waypoints to the end of the existing route, and **replace in place only a waypoint of the same name** — never wipe the route.

This lot also **reverts FIX-DEFAULTS-AIRCRAFT-ROSTER** (#438): emptying the default spawnables/dynamic-slot-templates was a misdiagnosis — injecting those late-activation/dyn-spawn groups is normal and intended; they were not the cause of the message.

**Branch**: `fix/waypoints-injection-preserve-route` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| FIX-WAYPOINTS-INJECT-PRESERVE-ROUTE-001 | `_inject_waypoints_into_group`: start from the group's existing route; append each injected waypoint at the end, replacing in place only a same-named waypoint; never recreate the route (takeoff/landing preserved); keep the ETA-locked guard and renumber `num`. Revert #438. Regression tests (takeoff preserved + append, replace-by-name). Verified end-to-end on the reporter's `test.miz`. | `waypoints_injector/waypoints_injector_worker.py`, `test/python/waypoints_injector/test_waypoints_injector_worker.py` | fix | ✅ |

### Future note (not in this lot)
- Prevent spawnable (`veafSpawn-`) and dynamic-slot template groups from being **selectable** in the DCS slot list (they appear as choosable slots today). To investigate.

---

## Lot FIX-DEFAULT-MODULES-ACTIVE — default mission.yaml ships an active modules block

**Goal**: A freshly-scaffolded mission's default `mission.yaml` had **every** module commented out → building it activated no module → **no VEAF F10 menu** in game. Per David, the default must mirror `convert-v5`'s baseline so a fresh mission works out of the box. Active set chosen (option C minus MISSILEGUARDIAN).

**Branch**: `fix/default-mission-yaml-active-modules` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| FIX-DEFAULT-MODULES-ACTIVE-001 | Default `mission.yaml` ships an **active** `modules:` block: mandatory infrastructure (bare) + `SECURITY`/`RADIO`/`GROUNDAI`/`SPAWN`/`NAMEDPOINTS`/`MOVE`/`GRASS`/`WEATHER`/`REMOTE`/`AIRBASES`/`INTERPRETER: true`; community scripts `false`; config-requiring modules (`ASSETS`, `QRA`, `SHORTCUTS`, `SANCTUARY`, combat, …) as commented examples. Mirrors convert-v5 baseline (IMC2-007 lockstep). | `src/defaults/mission-folder/mission.yaml` | fix | ✅ |

---

## Lot FIX-DEFAULTS-MODULES — MiST mandatory, drop WEATHERMARK from default

**Goal**: David's review of the default `mission.yaml`: (1) MiST is a hard VEAF dependency → must always be injected (like the mandatory infrastructure modules); (2) WEATHERMARK no longer belongs in our scripts → remove it from the default (full removal tracked separately); (3) TUM has no initialization in the generated config (kept in the default; init tracked separately).

**Branch**: `fix/defaults-mist-weathermark-tum` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| FIX-DEFAULTS-MODULES-001 | MiST mandatory: always inject the `mist` community script regardless of the `modules:` entry (`MANDATORY_COMMUNITY_SCRIPTS`); a bare `MIST:` is the default form (silent), an explicit `MIST: false` is warned and ignored. Default lists `MIST:` in the mandatory infrastructure block. Remove `WEATHERMARK` from the default. Tests for MiST-kept-when-disabled. | `mission_builder/mission_builder_worker.py`, `src/defaults/mission-folder/mission.yaml`, locales, `test/python/` | fix | ✅ |

---

## Lot FIX-BUILD-COPY-DEFAULTS — copy default mission.yaml before reading config

**Goal**: When the user has no `mission.yaml`, `build` resolved the config from the absent file in `MissionBuilderWorker.__init__` **before** `complete_src_folder_with_defaults()` (run later in `work()`) copied the default into the folder. Result: `self.mission_yaml` (and everything derived — `veaf-config.lua`, community toggles, custom_scripts, dynamic_mode) stayed empty → **no veaf-config.lua, no VEAF menu**, and all community scripts wrongly enabled. Fix the ordering so the default is available before the config is read.

**Branch**: `fix/build-copy-defaults-before-read` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| FIX-BUILD-COPY-DEFAULTS-001 | Add `_ensure_default_mission_yaml()` called at the very start of `__init__` (before the mission.yaml read): copy the default mission.yaml from `<scripts_path or mission/published/src>/defaults/mission-folder/` into the mission folder if missing. The later `complete_src_folder_with_defaults()` still copies the other defaults. Tests: absent mission.yaml → copied + config resolved (veaf-config, MiST kept, SKYNET off); existing mission.yaml not overwritten. | `mission_builder/mission_builder_worker.py`, `test/python/` | fix | ✅ |

---

## Lot WEATHERMARK-REMOVE — retire the WeatherMark community script

**Goal**: WEATHERMARK is no longer used by VEAF. Remove it everywhere now that the default no longer references it.

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| WEATHERMARK-REMOVE-001 | Remove the `weathermark` community script: drop `src/scripts/community/WeatherMark.lua`, the `weathermark` entry in `get_community_script_files()`, any validator/i18n references, and the documentation. Ensure no build/convert path still references it. | `mission_tools/mission_constants.py`, `src/scripts/community/`, `doc/`, `test/python/` | chore | ✅ |

---

## Lot TUM-INIT — initialize TheUniversalMission from config

**Goal**: `TUM: true` in `mission.yaml` currently does nothing — the generated `veaf-config.lua` never calls `TUM.initialize()` (the runtime logs "loaded, but not initialized"). Generate the init so the toggle actually starts TUM.

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| TUM-INIT-001 | Emit `TUM.initialize()` in `veaf-config.lua` when `TUM` is enabled (decide config surface, e.g. a `settings:` block). Add tests. | `veaf_libs/lua_config_generator.py`, `mission_builder/mission_builder_worker.py`, `test/python/` | feat | ✅ |

---

## Lot BUILD-AUTOVERSION — auto-compute the release build number

**Goal**: `veaf-build` should derive the release version automatically instead of requiring `--version`. Scheme is `X.Y.Z.BUILD`.

Algorithm:
1. Read the **project base version** from `pyproject.toml` (`X.Y.Z`, e.g. `6.4.20`).
2. If `published.zip` exists, read its **published version** (from `veaf-version.json` inside it, e.g. `6.4.20.3`).
3. If the published version shares the **same base** as the project (`6.4.20` == `6.4.20`) → **increment the build number** (`6.4.20.3` → `6.4.20.4`).
4. Otherwise (different base, e.g. project bumped to `6.4.21`, or no `published.zip`) → start from the project base with **build number 1** (`6.4.21.1`).

Notes: `--version` should remain an explicit override. Keep the provenance/version stamping (`veaf-version.json`) consistent. Add unit tests for each branch (same base → +1, new base → .1, no zip → .1).

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| BUILD-AUTOVERSION-001 | Compute the release `X.Y.Z.BUILD` from project base vs `published.zip` version per the algorithm above; `--version` overrides; tests for each branch. | `veaf_build/`, `test/python/` | feat | ✅ |

---

## Lot SECREV — Full-repo code review findings

**Goal**: Fix the security and correctness defects surfaced by the full-repository code review. Two are release-blocking: arbitrary code execution when parsing any `.miz` file, and silent data loss when extracting helicopter groups.

**Branch**: `fix/secrev-findings` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| SECREV-001 | **RCE**: `luadata.unserialize()` runs `lua.execute(raw)` on untrusted `.miz` content via an unsandboxed lupa runtime. Route `.miz` parsing through the existing pure-Python `_unserialize()` state machine (preferred), or harden the runtime (`register_eval=False`, strip `os`/`io`/`load`/`loadfile`/`dofile`/`package`/`require` from globals, bound `max_memory`). Add regression tests with a malicious `.miz` payload asserting no execution. | `luadata/serializer/unserialize.py`, `mission_tools/miz_tools.py`, `test/python/` | fix | ✅ |
| SECREV-002 | **Data loss**: helicopter-matching block (lines 1075-1086) is dedented one level, so only the last helicopter group per country is extracted. Re-indent into the `for group` loop. Regression test: extract a mission with ≥2 helicopter groups in one country, assert all present. | `aircrafts_injector/aircrafts_injector_worker.py`, `test/python/` | fix | ✅ |
| SECREV-003 | Replace `eval()` in the time-expression parser with a safe AST-based arithmetic evaluator (or numeric/operator allowlist); guard against DoS expressions. Tests for valid and rejected inputs. | `weather_injector/utils/time_expression_parser.py`, `test/python/` | fix | ✅ |
| SECREV-004 | **Zip Slip**: validate every member name before `extractall` (reject absolute paths and entries escaping the destination) in `.miz` extraction and the updater. | `mission_tools/miz_tools.py`, `veaf-tools-updater.py`, `test/python/` | fix | ✅ |
| SECREV-005 | **Zip-bomb**: cap total uncompressed size and entry count before extracting `.miz` and `published.zip`. | `mission_tools/miz_tools.py`, `veaf-tools-updater.py`, `test/python/` | fix | ✅ |
| SECREV-006 | `convert_weather` truthiness guards (`if temp := ...`) silently drop legitimate `0` values (temperature, wind speed/direction, visibility). Use `is not None`. Tests for zero-valued weather params. | `mission_builder/v5_pipeline_converters.py`, `test/python/` | fix | ✅ |
| SECREV-007 | Lua nil-deref crashes: `spawnConvoy` `size / 2` without nil-guard (`veafSpawnGround.lua:635`); `generateAirDefenseGroup` mutates nil group after error (`veafCasMission.lua:763`); `getAtcForCarrierOperations`/`stopCarrierOperations` deref carrier before nil-check (`veafCarrierOperations.lua:662,789`). Add guards + luaunit tests. | `src/scripts/veaf/veafSpawnGround.lua`, `veafCasMission.lua`, `veafCarrierOperations.lua`, `test/lua/` | fix | ✅ |
| SECREV-008 | `veafAirWaves.addWave` string-list branch inserts the whole `parameter` table instead of element `s` (`veafAirWaves.lua:307`). Fix + test. | `src/scripts/veaf/veafAirWaves.lua`, `test/lua/` | fix | ✅ |
| SECREV-009 | `veafSecurity`: stop logging the cleartext password at debug (`:552`); fix `isAuthenticated` reading the never-assigned `veafSecurity.SecurityDisabled` instead of `veaf.SecurityDisabled` (`:656`). | `src/scripts/veaf/veafSecurity.lua`, `test/lua/` | fix | ✅ |
| SECREV-010 | `veafMove.markTextAnalysis` mandatory-group guard never fires (`groupName` defaults to `""`, truthy). Reject empty group name (`veafMove.lua:240`). Fix + test. | `src/scripts/veaf/veafMove.lua`, `test/lua/` | fix | ✅ |

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
| CI-NODE24-004 | Trigger each workflow (or wait for natural runs) and confirm the Node.js 20 deprecation annotation no longer appears | CI runs | chore | ✅ |
| CI-NODE24-005 | Follow-up: `docs-chatbot-index.yml` was missed by 001-003 and still ran `actions/setup-node@v4` + `actions/cache@v4` (Node 20). Bumped both to `@v5` (Node 24). | `.github/workflows/docs-chatbot-index.yml` | chore | ✅ |
| CI-NODE24-006 | Exhaustive sweep over all 9 workflows caught a second miss: `peter-evans/create-pull-request@v7` (Node 20) in `dcs-data-drift.yml`. Bumped to `@v8` (Node 24; runtime-only, no input/behaviour change). No Node 20 action remains in any workflow. | `.github/workflows/dcs-data-drift.yml` | chore | ✅ |

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
| MODULES-UNIFY-001 | Redesign the `mission.yaml` schema: one `modules:` block, each module/community-script an entry with nested config (incl. `skynet`, `ctld`, `csar`, `qra`). Update the default template and the validator. | `src/defaults/mission-folder/mission.yaml`, `veaf_libs/yaml_validator.py` | feat | ✅ |
| MODULES-UNIFY-002 | `lua_config_generator`: read nested per-module config from `modules:`; drop all handling of `external_modules:` and top-level `qra:`. | `veaf_libs/lua_config_generator.py`, `test/python/` | feat | ✅ |
| MODULES-UNIFY-003 | `convert-v5`: emit converted modules (incl. QRA) into the new nested `modules:` structure instead of separate `external_modules:`/`qra:` sections. | `mission_builder/config_migrator.py`, `mission_builder/v5_converter.py`, `test/python/` | feat | ✅ |
| MODULES-UNIFY-004 | `convert-v5`: extract CTLD/CSAR config from `missionConfig.lua` (`ctld.xxx = …` / `csar.xxx = …` assignments) into `modules.CTLD` / `modules.CSAR`. (todo item 6) | `mission_builder/config_migrator.py`, `test/python/` | feat | ✅ |
| MODULES-UNIFY-005 | Update docs: `doc/MISSION_YAML_REFERENCE.md` (+ `.fr`), migration guide, and any example referencing `external_modules:`/`qra:`. | `doc/MISSION_YAML_REFERENCE*.md`, `doc/mission-maker/MIGRATION_GUIDE*.md` | chore | ✅ |
| MODULES-UNIFY-006 | Add **semantic** validation of the unified `modules:` block — distinct from the YAML *syntax* validation already provided by `yaml_validator.validate_yaml_file`. Today `lua_config_generator` reads `modules:` as raw nested dicts with silent `.get(key, default)` (`:349-458`), so an unknown module key, an unrecognized `init:` parameter, or a wrong scalar type is silently dropped and produces wrong Lua with no warning to the mission-maker. Validate: unknown module key → error, unrecognized `init:` param → warning, wrong type → error. Reuse the localized `ValidationError` style already rolled out in `aircrafts_injector_worker` (`:31`, `:114-297`) for consistency; consider promoting it (and the existing `weather_injector/models/` config models) toward a shared typed `mission.yaml` model. | `veaf_libs/yaml_validator.py`, `veaf_libs/lua_config_generator.py`, `test/python/` | feat | ✅ |

---

## Lot TODO0609-CONVERT-FIDELITY — convert-v5 report & extraction fidelity

**Goal**: Make the `convert-v5` annotated report (`convert-v5-report.md`) and YAML output faithfully reflect what was migrated, so the mission-maker can spot at a glance the v5 code that was NOT auto-migrated and decide what to do (migrate by hand, report a bug, move to `mission-script.lua`). Covers todo-2026.06.09 items 4, 9, 10.

> Depends on TODO0609-MODULES-UNIFY for the target YAML shape that commented-out elements (-001) are emitted into.

**Branch**: `feat/convert-fidelity` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| CONVERT-FIDELITY-001 | Re-parse commented-out v5 elements (any extractable module, e.g. a commented `combatZone_Abu_al_Duhur`) and re-emit them as **commented** YAML in `mission.yaml`, instead of silently dropping them. (todo item 4) | `mission_builder/config_migrator.py`, `mission_builder/v5_converter.py`, `test/python/` | feat | ✅ |
| CONVERT-FIDELITY-002 | In the annotated `missionConfig`, comment out the **entire** `if veafXxx then … end` init block of a migrated module (not only the `initialize()` line), so non-migrated code visually stands out. (todo item 9) | `mission_builder/config_migrator.py`, `test/python/` | feat | ✅ |
| CONVERT-FIDELITY-003 | Add `mission.silence_atc_on_all_airbases` to the default `mission.yaml` (value `true`) and emit the corresponding Lua. At conversion, scan `missionConfig.lua` for an active `veaf.silenceAtcOnAllAirbases()` call → `true`, else `false`. (todo item 10) | `src/defaults/mission-folder/mission.yaml`, `veaf_libs/lua_config_generator.py`, `mission_builder/config_migrator.py`, `test/python/` | feat | ✅ |
| CONVERT-FIDELITY-004 | Prepend a numeric summary header to `convert-v5-report.md` (e.g. "N modules migrated · M need manual action (lines …)") so the mission-maker sees at a glance whether work remains, without reading the full annotated config. Drives off the same data the annotation pass already computes. | `mission_builder/v5_converter.py`, `mission_builder/config_migrator.py`, `test/python/` | feat | ✅ |

> **001 done** (follow-up PR): a de-commented re-extraction of `missionConfig.lua` is diffed against the active `mission.yaml`; lines present only because of previously-commented elements are appended as a fully-commented "Commented-out v5 elements" block (generic — covers every extractor; pattern-based extraction filters prose). Covers all extractable types at once.

## Lot TODO0609-ERA-AUTODETECT — Automatic mission era detection

**Goal**: The mission era (especially `WW2`) is currently manual or extracted from v5 only if present. Add automatic detection from the `.miz` content when `era` is not provided. A manual `mission.yaml` `era` always wins. Covers todo-2026.06.09 item 7.

**Decision** (grilling 2026-06-10): combined heuristic — mission year **and** WW2-era unit/aircraft types — with a `mission.yaml` override that always takes precedence.

**Branch**: `feat/era-autodetect` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| ERA-AUTODETECT-001 | Detection helper combining the DCS mission year and a WW2 unit/aircraft-type reference list to infer the era; document the priority rule. Unit tests over fixtures (WW2 by year, WW2 by units, modern, ambiguous). | `mission_builder/`, `test/python/` | feat | ✅ |
| ERA-AUTODETECT-002 | Wire the helper into conversion/build: use detected era only when `mission.yaml` `era` is absent; manual value always wins. Maintain the WW2-era types reference table. | `mission_builder/config_migrator.py` / `mission_builder/mission_builder_worker.py`, `test/python/` | feat | ✅ |

---

## Lot TODO0609-SPAWN-EXTERNALIZE — Externalize spawn group definitions to YAML

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

---

## Lot TODO0609-DYNLOAD-CLARIFY — Clarify dynamic script loading

**Goal**: Understand and document the two dynamic-loading files — `VeafDynamicLoader.lua` (loads VEAF scripts) and `veafDynamicConfig.lua` (loads mission scripts) — determine whether one is obsolete, and clarify the overall static-vs-dynamic loading of VEAF scripts (including how `convert-v5` handles legacy v5 dynamic-loading triggers). Covers todo-2026.06.09 item 2.

**Branch**: `chore/dynload-clarify` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| DYNLOAD-CLARIFY-001 (spike) | Trace and document both files' roles and the static/dynamic loading flow; identify any obsolete artifact and propose its removal; document the conversion behaviour for legacy dynamic-loading triggers. Deliverable: doc update + cleanup tickets if needed. | `src/defaults/mission-folder/src/scripts/veafDynamicConfig.lua`, `src/scripts/VeafDynamicLoader.lua`, `mission_builder/mission_builder_worker.py`, `doc/` | spike | ✅ |

**Spike result (DYNLOAD-CLARIFY-001)** — see [ADR 0004](docs/adr/0004-dynamic-script-loading.md):

- **Neither file is obsolete.** They are two layers of the same dynamic-loading mechanism: `VeafDynamicLoader.lua` (`src/scripts/`) loads the **VEAF framework** modules (`src/scripts/veaf/*.lua`) from `VEAF_DYNAMIC_SCRIPTSPATH`; `veafDynamicConfig.lua` (mission scaffold) loads the **mission's** scripts from `VEAF_DYNAMIC_MISSIONPATH`. Both are referenced by the build's injected triggers (3 and 5 respectively).
- **Loading flow**: the build injects six paired triggers (set-path ×2, dynamic/static for VEAF scripts, dynamic/static for mission scripts). Dynamic mode `loadfile`s from disk (dev/test, live iteration); static mode `a_do_script_file`s scripts embedded as `.miz` map resources (distribution) and bypasses both loader files.
- **No cleanup tickets** for these two files.
- **Deferred**: whether a legacy v5 mission's own VEAF loading triggers are removed during `build --migrate-from-v5` (the build prepends its six triggers and shifts existing ones up without inspecting them) is owned by **TODO0609-TRIGGERS-VERIFY**, not this spike.

---

## Lot TODO0609-PRESETS-FIDELITY — Iso-functional radio presets conversion

**Goal**: v5 presets encode DCS module quirks (e.g. Mi-24 channel 0 mapped to channel 20 on injection, AJS-37 offsets). The current `convert-v5` loses these. First make conversion iso-functional with the v5 mission; then analyse whether the v6 `presets.yaml` data structure is adequate (the v5 structure may have been better) and propose enriched defaults. Covers todo-2026.06.09 item 13.

**Branch**: `fix/presets-fidelity` → PR → `develop-v6` (13a); follow-up branch for 13b once the spike lands

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| PRESETS-FIDELITY-001 (13a) | Make `convert-v5` produce a `presets.yaml` iso-functional with the v5 mission's presets — preserve per-module channel mappings/offsets (Mi-24 ch0→20, AJS-37, …). Regression tests against real v5 preset fixtures. | `mission_builder/v5_pipeline_converters.py`, `presets_injector/`, `test/python/` | fix | ✅ |
| PRESETS-FIDELITY-002 (13b, spike) | Analyse the v6 `presets.yaml` data structure vs the v5 presets structure; decide whether to redesign it; propose a default `presets.yaml` that accounts for DCS module quirks. Deliverable: reco + tickets. | `presets_injector/`, `src/defaults/mission-folder/src/presets.yaml` | spike | ✅ |

---

## Lot TODO0609-TRIGGERS-VERIFY — Verify trigger migration for custom scripts

**Goal**: DCS trigger migration is automatic (`build --migrate-from-v5`). Verify with Flogas the behaviour of triggers for **custom scripts** (custom-script loading) and confirm nothing is lost or mis-handled. Covers todo-2026.06.09 item 3. External dependency: Flogas's input/missions.

**Field feedback (IMC-Day second round, `tests-mct6-imcday(3).md` §9, tested on 6.4.0)** confirms the need and adds three concrete defects, ticketized below: the legacy v5 dynamic-loading triggers are not recovered by the migration ([VEAF-mission-converter#17](https://github.com/VEAF/VEAF-mission-converter/issues/17), explicitly deferred to this lot by ADR 0004), the injected loading triggers are recreated on every build so user customizations of load order are lost (possible in MCT 5), and the legacy "CTLD beacons loading" trigger survives migration even when CTLD is disabled.

**Branch**: `fix/triggers-verify` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| TRIGGERS-VERIFY-001 | Verify, with Flogas, how custom-script triggers are migrated by `build --migrate-from-v5`; document findings; open fix tickets if a defect is confirmed. | `mission_builder/mission_builder_worker.py`, `doc/` | chore | ✅ |
| TRIGGERS-VERIFY-002 | `build --migrate-from-v5` does not recover the mission's existing v5 dynamic-loading triggers (`dynamicLoader` in the *VEAF scripts loading* trigger, `dynamicConfig` in *mission script loading*): the build prepends its six triggers and shifts existing ones up without inspecting them (ADR 0004 deferred item). Detect the legacy loading triggers, migrate them into the v6 mechanism, and remove the obsolete ones. **Finding: already handled** — `clear_veaf_triggers` removes the six v5 loading triggers by their condition strings (`return VEAF_DYNAMIC_PATH…`) before the v6 ones are inserted (verified empirically on the v5 demo mission: 14→8 actions). No code change needed. | `mission_builder/mission_builder_worker.py`, `test/python/` | fix | ✅ |
| TRIGGERS-VERIFY-003 | The injected loading triggers are recreated on every build, so they can drift from what the dynamic loader actually does and any user customization (MCT 5 allowed editing the "config" loading triggers, e.g. to load scripts before/after) is lost. Decide and implement how load order / trigger content can be preserved or parameterized across builds. **Deferred**: design spike, no consumer demand yet; load order is owned by `mission.yaml` (`pipeline`/script order) in v6, so editing the generated triggers by hand is discouraged. Revisit if a user needs pre/post hooks. | `mission_builder/mission_builder_worker.py`, `doc/`, `test/python/` | spike | ⬜ |
| TRIGGERS-VERIFY-004 | The legacy "CTLD/CSAR sound preload" trigger (an `out_sound` trigger registering `beacon.ogg` / `beaconsilent.ogg` / `CSAR.ogg` …, present in v5 missions, not injected by the build) survives the build even when both CTLD and CSAR are disabled. Remove it (and its mapResource entries) during the build when **both** CTLD and CSAR are off; keep it when either is enabled. Re-creating/packaging it when a module is enabled is the `BUILD-COMMUNITY-SOUNDS` lot. | `mission_builder/mission_builder_worker.py`, `mission_tools/mission_constants.py`, `test/python/` | fix | ✅ |

---

## Lot BUILD-COMMUNITY-SOUNDS — Build owns CTLD/CSAR sound preloading

**Goal**: Make the build responsible for the community-script sound assets, so a mission does not have to carry them by hand. Today the `.ogg` files (CTLD: `beacon.ogg`, `beaconsilent.ogg`, `radiobeep.ogg`; CSAR: `CSAR.ogg`, `csar-beacon.ogg`) live only in the mission's own `src/mission/l10n/DEFAULT/` and are registered by a hand-made v5 `out_sound` trigger. `TRIGGERS-VERIFY-004` only *removes* that trigger when both modules are off; this lot covers the *add* side (David: "ajouter si CTLD ou CSAR enabled" + "du coup oui" the build should package the sounds itself).

**Resolved design** (David: "fichiers seuls"): CTLD/CSAR play their sounds **by filename** at runtime (`outSoundForCoalition("beacon.ogg")`, `outSoundForGroup("l10n/DEFAULT/CSAR.ogg")`), so the v5 `out_sound` trigger and the `mapResource` registration are **not** needed — packaging the `.ogg` in `l10n/DEFAULT/` is sufficient. Empirically confirmed the exact sound set per module:
- CTLD: `beacon.ogg`, `beaconsilent.ogg`, `radiobeep.ogg`
- CSAR: `beacon.ogg` (shared), `CSAR.ogg`

`csar-beacon.ogg` is not referenced anywhere and was dropped from the mapping. `radiobeep.ogg` (JTAC fallback beep, CTLD only) is **not redistributed by upstream** and is left to the mission maker — the build warns when an enabled module's required sound is shipped by neither the tools nor the mission. Assets flow into `published.zip` automatically (the release packager already includes all of `src/scripts/community/**`).

**Branch**: `feat/build-community-sounds` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| BUILD-COMMUNITY-SOUNDS-001 | Ship the CTLD/CSAR sound assets (`beacon.ogg`, `beaconsilent.ogg`, `CSAR.ogg`) under `src/scripts/community/sounds/` and inject the ones a mission is missing into `l10n/DEFAULT/` when CTLD or CSAR is enabled (mission-provided sounds win; nothing when both off; warn on a required sound shipped by neither tool nor mission). Files-only — no `mapResource` entry, no `out_sound` trigger. | `mission_builder/mission_builder_worker.py`, `mission_tools/mission_constants.py`, `src/scripts/community/sounds/`, `test/python/` | feat | ✅ |
| BUILD-COMMUNITY-SOUNDS-002 | Add `radiobeep.ogg` (JTAC fallback beep) to the shipped assets once a redistributable source is available (David to provide). | `src/scripts/community/sounds/` | feat | ⬜ |

---

## Lot TODO0609-TUI-FOLDER-HINT — Clarify the TUI mission-folder default

**Goal**: In the TUI, the mission-folder prompt shows a bare `.` default, which is not obviously the current directory. Add an explanatory label and show the resolved absolute path. Covers todo-2026.06.09 item 11.

**Branch**: `feat/tui-folder-hint` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| TUI-FOLDER-HINT-001 | Enrich the mission-folder prompt: explanatory label (`. = current folder`, FR/EN) and display the resolved absolute path as a hint. Update locales and tests. | `veaf_libs/tui.py`, locales, `test/python/` | feat | ✅ |

---

## Lot TODO0609-AIRCRAFT-INJECT — Split aircraft-group injection (spawnable vs dynamic-slot template)

**Goal**: Restore the historically-distinct handling of two separate uses of injected aircraft groups that was half-lost in the Python rewrite: **(B) spawnable aircraft groups** cloned at runtime by `veafSpawn` (name prefix `veafSpawn-`) and **(C) dynamic-slot templates** consumed natively by DCS (`dynSpawnTemplate == true`). Two separate, independently-configurable pipeline steps; reliable flag/prefix-based sorting. Source: `HANDOFF-aircraft-groups-injection.md`. This is the analysis behind todo-2026.06.09 item 12 (the defaults files are legitimate and kept; `spawnables.yaml` "doesn't serve" because no step injects it — a pipeline bug).

**Frozen decisions** (see `CONTEXT.md` and `docs/adr/0002-aircraft-group-injection-sort-criteria.md`): two distinct features sharing one extract/inject tool; sort by `dynSpawnTemplate` flag (priority) then `veafSpawn-` prefix, else ignore; **drop the legacy `.*[tT]emplate.*` name sort** (root cause of the historical misrouting bug).

**Branch**: `feat/aircraft-inject` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| AIRCRAFT-INJECT-001 | Replace the single `aircraft_groups` pipeline step with two: `spawnable_aircrafts` (→ `src/spawnables.yaml`) and `dynamic_slot_templates` (→ `src/dynamic-slot-templates.yaml`), each independently configurable (`true/false` or `{enabled, file, mode}`). Hard break: old step + `aircraft-templates.yaml`/`templates.yaml` names dropped (legacy-file warning kept). | `veaf_tools/commands/build.py`, `mission_builder/mission_builder_worker.py`, `test/python/` | feat | ✅ |
| AIRCRAFT-INJECT-002 | Keep both default files in `src/defaults/mission-folder/src/` — `spawnables.yaml` (B) and `dynamic-slot-templates.yaml` (C, renamed from `templates.yaml`); update the defaults mapping + tests. Removed the now-dead `lua_module` defaults-copy branch. | `src/defaults/mission-folder/src/`, `mission_builder/mission_builder_worker.py`, `test/python/` | feat | ✅ |
| AIRCRAFT-INJECT-003 | Flag/prefix sort in the extractor via shared `classify_aircraft_group` (route each group to B or C, ignore the rest); one pass emits both files by default, `--kind` restricts. Helicopters indentation bug was already fixed by SECREV-002 (no double-fix needed). | `aircrafts_injector/aircrafts_injector_worker.py`, `test/python/` | fix | ✅ |
| AIRCRAFT-INJECT-004 | Two injection steps, each injecting its file as-is (no name regex); `add`/`replace` mode per step. | `aircrafts_injector/aircrafts_injector_worker.py`, `veaf_tools/commands/build.py`, `test/python/` | feat | ✅ |
| AIRCRAFT-INJECT-005 | `convert-v5`: produces **both** v6 files from the v5 `settings.lua`, applying the same flag/prefix sort; updated `V5_PIPELINE_CANDIDATES` / `V6_PIPELINE_CANDIDATES`. | `mission_builder/v5_pipeline_converters.py`, `mission_builder/v5_converter.py`, `test/python/` | feat | ✅ |
| AIRCRAFT-INJECT-006 | Cleanup: fixed the dead `.vscode/launch.json` reference; realigned `doc/mission-maker/scripts/veafSpawn.md` (+ `.en`), `doc/MISSION_YAML_REFERENCE*.md`, `doc/PIPELINE_REFERENCE*.md` on the real schema + the B/C distinction. | `.vscode/launch.json`, `doc/` | chore | ✅ |

**Open questions — settled with David (2026-06-11)**: (1) (C) file → **`dynamic-slot-templates.yaml`**; (2) step names → **`spawnable_aircrafts`** + **`dynamic_slot_templates`**; (3) **hard break** (old step/names dropped, ADR 0001 precedent); (4) extraction → **one pass writes both files by default**, `--kind spawnable|dynamic-template` restricts to one; (5) warehouse wiring → **separate lot DYNSLOT-WAREHOUSE** (handoff §5, deferred).

**Field feedback integrated** (IMC-Day 2026-06-10, tested on 6.4.0 — `tests-mct6-imcday(3).md` §8):
- The orphan warning (FIX-AIRCRAFT-ORPHAN) flagged `aircraft-templates.yaml` while the step actually consumed `templates.yaml` — the split removes that mismatch; pre-v6 names now emit a clear "ignored, use the new files" migration message (param-ized by file). Residual `aircraft-templates.yaml` references purged from `build.py` message, `lua_config_generator` comment, TUI, and the injector/extractor READMEs.
- Deleted defaults silently reappeared: confirmed `complete_src_folder_with_defaults` logs `builder.copied_from_defaults` on every recopy, and skips when the step is disabled (regression test added).
- `spawnables.yaml` was copied but injected by no step (the lot's root motivation): the `spawnable_aircrafts` step now consumes it — acceptance test asserts `resolve_pipeline_step_file` wires `src/spawnables.yaml`.
- Fixed a TUI regression introduced mid-lot: `extract-aircraft-groups` no longer passes the removed `--output-yaml` (now `--kind`); `inject-aircraft-groups` defaults to `src/spawnables.yaml`.

---

## Lot DYNSLOT-WAREHOUSE — Wire dynamic-slot templates into the `.miz` warehouses

**Goal**: Injecting a `dynSpawnTemplate=true` group puts the **group** in the mission, but for DCS to actually offer it as a Dynamic Slot the `.miz` **`warehouses`** file must also reference it (`airports[id].dynamicSpawn=true` + aircraft list). The current injector does not touch `warehouses`. Split off from AIRCRAFT-INJECT (handoff §5). Reference: `test/veaf-tools/demo-mission/src/mission/warehouses` (`dynamicSpawn = true`).

**Spike findings (001 ✅)**: Dynamic Slots are **per airbase** — `warehouses.airports[<id>].dynamicSpawn = true` enables them; `aircrafts[<type>]` is the warehouse stock; **`aircrafts[<type>].linkDynTempl = <groupId>`** links the slot to a `dynSpawnTemplate=true` group (the model providing loadout/livery/radio/route — confirmed in the demo: `linkDynTempl=2114` ↔ group "DST - UH-1H" groupId 2114). The template group's physical placement is irrelevant. The airport key `<id>` is the DCS **airdrome id**; warehouses carry no names, and the datamine has no airdrome table — but each airport block has a `coalition` field (so "all airports of a coalition" needs no names), and name→id is recoverable from the **install** (`Mods/terrains/*/Beacons.lua`). Config model (David): `warehouses.yaml` per coalition (undeclared → untouched); per coalition global defaults (fuel/weapons/aircraft+templates) applied to all coalition airports, or a specific airport list (by name or id) with overrides; the build sets `dynamicSpawn`, stock, fuel and `linkDynTempl`.

**Branch**: `feat/dynslot-warehouse` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| DYNSLOT-WAREHOUSE-001 (spike) | Investigate the `warehouses` Dynamic-Slot schema and design the wiring. **Done** — see findings above. | `mission_tools/`, `doc/` | spike | ✅ |
| DYNSLOT-WAREHOUSE-002 | Airdrome name→id table (prerequisite for naming airbases): `airdromes.yaml` generated from a DCS install's terrain `Beacons.lua` (`update-dcs-data --airdromes --dcs-path`), resolver `veaf_libs.dcs_airdromes`, bundled in the exe; install-dependent (not CI-guarded). | `veaf_build/dcs_data/airdromes.py`, `veaf_libs/{data/airdromes.yaml,dcs_airdromes.py}`, `veaf_build/cli.py`, `test/python/` | feat | ✅ |
| DYNSLOT-WAREHOUSE-003/004/005 | `warehouses_injector`: `warehouses.yaml` schema + a new `warehouses` build pipeline step (after aircraft injection) that selects airports (all-of-coalition via the `coalition` field / by id / by name via the airdrome table + mission theatre), sets `dynamicSpawn` + fuel/munitions + aircraft stock, and wires `aircrafts[<type>].linkDynTempl` from each injected `dynSpawnTemplate` group's `groupId` (by group name, else by aircraft type). Per-airport overrides are supported. | `warehouses_injector/`, `veaf_tools/commands/build.py`, `mission_builder/` (defaults map), `test/python/` | feat | ✅ |
| DYNSLOT-WAREHOUSE-006 | Commented `src/defaults/mission-folder/src/warehouses.yaml` (no-op default) + FR/EN docs (`PIPELINE_REFERENCE`, `MISSION_YAML_REFERENCE`) + tests. | `src/defaults/`, `doc/`, `test/python/` | feat | ✅ |
| DYNSLOT-WAREHOUSE-NAMES (follow-up) | Broaden airdrome name coverage to beacon-less maps (e.g. Normandy/WW2) via another install source if needed. | `veaf_build/dcs_data/airdromes.py` | feat | ⬜ |

---

## Lot TODO0609-DEFAULTS-AUDIT — Audit the defaults mission-folder for dead files

**Goal**: `prepare` copies the whole `src/defaults/mission-folder/` tree into a new mission via `rglob` (`prepare.py:68`), so any leftover file ships to users. The aircraft YAML files are legitimate (see TODO0609-AIRCRAFT-INJECT). Audit the rest to confirm nothing else is dead weight. Covers todo-2026.06.09 item 12.

**Branch**: `chore/defaults-audit` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| DEFAULTS-AUDIT-001 | Audit each file under `src/defaults/mission-folder/` for whether it is actually consumed at first build (candidates to verify: `src/presets.md`, `src/README-versions.md`, `src/options`). Report role + used/unused per file; remove or document anything genuinely dead. Exclude the aircraft YAML (owned by TODO0609-AIRCRAFT-INJECT). | `src/defaults/mission-folder/`, `doc/` | chore | ✅ |

**Audit result (DEFAULTS-AUDIT-001)**: the suspected dead files `src/presets.md` and `src/README-versions.md` are **no longer present** in the scaffold (already removed). Every remaining file is consumed at first build — none is dead:

| File | Role | Status |
|------|------|--------|
| `.gitignore` | Scaffolds the user repo to ignore generated/downloaded artifacts (`/published/`, `/build/`, `veaf*.exe`, `*.miz.bak`) | used (scaffold) |
| `mission.yaml` | Main build configuration (modules, identity, missions) | used |
| `src/options` | DCS options table injected into the `.miz` (`miz_tools.py` options injection) | used |
| `src/presets.yaml` | Radio presets — `presets` pipeline step | used |
| `src/spawnables.yaml` | Predefined spawnable groups — SPAWN module | used |
| `src/templates.yaml` | Aircraft-group templates — SPAWN module (owned by AIRCRAFT-INJECT) | used (excluded from this audit) |
| `src/versions.yaml` | Weather/time variants — `weather` pipeline step | used |
| `src/waypoints.yaml` | Bullseye / navigation points — `waypoints` pipeline step | used |
| `src/scripts/mission-script.lua` | User custom Lua, loaded after generated `veaf-config.lua` | used |
| `src/scripts/veafDynamicConfig.lua` | Dynamic script-loading config (dev/test live-reload) | used |

Conclusion: nothing to remove. The `doc/mission-maker/GUIDE` project-layout tree (FR/EN) was corrected to list every shipped default with its role, so the structure documentation now matches reality.

---

## Lot UXPILOT-FEEDBACK — Surface command errors to pilots

**Goal**: A pilot who mistypes an F10 marker command usually gets **no feedback**, and error surfacing is inconsistent across modules. `veafSpawnAircraft` (`:67`) and `veafShortcuts` (`:625`) call `trigger.action.outText(...)`, but `veafNamedPoints.executeCommand` returns `false` silently and `veafSpawnParser` silently ignores unrecognized parameters (47-rule if-chain). A handler that crashes only logs to the DCS log — invisible in-game. Establish one feedback path and a global safety net so pilot mistakes and runtime errors are always visible.

**Branch**: `feature/uxpilot-feedback` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| UXPILOT-001 | **Global safety net**: the `veafMarkers.onEvent` dispatch (already `pcall`-wrapped + logged) now also surfaces a short in-game message to the placing coalition when a handler errors; the stack stays in the DCS log. luaunit tests (handler raises → reportToPilot called; success → not called). | `src/scripts/veaf/veafMarkers.lua`, `test/lua/` | feat | ✅ |
| UXPILOT-002 | **Unified feedback helper**: added `veaf.reportToPilot(message, duration, coalition)` (thin wrapper over `outText` / `outTextForCoalition`), used by 001 and 003. **Note**: the planned `veafNamedPoints.executeCommand` routing was dropped — its `markTextAnalysis` never returns nil when the keyphrase is present, so the "parse failed" branch is unreachable (no genuine silent failure to route there). | `src/scripts/veaf/veaf.lua`, `test/lua/` | feat | ✅ |
| UXPILOT-003 | **Unknown-parameter hints**: `markTextAnalysis` now collects unrecognized parameter keys into `options.unknownParameters` (skipping the command keyphrase), with a nearest-key suggestion via `veaf.nearestMatch` (Levenshtein); `veafSpawn.executeCommand` reports them to the placing pilot. Known keys live in `veafSpawn.KnownParameterKeys`. luaunit tests (unknown collected, typo→suggestion, valid input clean). | `src/scripts/veaf/veafSpawnParser.lua`, `src/scripts/veaf/veafSpawnCore.lua`, `src/scripts/veaf/veaf.lua`, `test/lua/` | feat | ✅ |

---

## Lot LUA-I18N — Localize in-game VEAF messages (Lua runtime; FR default + EN)

**Goal**: The Lua runtime (scripts executing inside DCS) has **no i18n** — every pilot-facing message (`trigger.action.outText*`) is a hardcoded **English** literal. Add a lightweight Lua i18n layer so in-game messages can be localized, with **French as the default** and English available. This is the runtime counterpart of the design-time i18n the Python tools already have (`veaf_libs.i18n` + `locales/{en,fr}.json`). Driver: UXPILOT-FEEDBACK shipped English-only pilot messages because there was nothing to localize against (see its note).

**Design constraints / open questions** (resolve in the spike):

- **Mechanism**: a `veaf.t(key, ...)` lookup over a catalog `{ key = { fr = "...", en = "..." } }`, with `string.format`-style interpolation and fallback (missing language → default FR → key).
- **Active language**: set once from `mission.yaml` (e.g. `language: fr|en`) → emitted by `lua_config_generator` into `veaf-config.lua` as `veaf.language` (default `"fr"`). DCS does **not** expose a reliable per-pilot UI language, so this is mission-global (not per-coalition/per-pilot) unless a cheap per-player signal is found.
- **Catalog location**: one Lua catalog module loaded by the framework (e.g. `veafI18n.lua`), vs per-module inline tables. Keep it test-friendly (`poetry run test-lua`).
- **Migration is incremental**: ship the framework + the UXPILOT pilot-feedback messages first; migrate the rest module-by-module (hundreds of `outText` literals — erode over time, do not big-bang).

**Branch**: `feat/lua-i18n` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| LUA-I18N-001 (spike) | Decide the mechanism, the active-language source (mission.yaml → `veaf-config.lua` → `veaf.language`, default FR), catalog layout, and fallback rules. Deliverable: design note + framework skeleton + tests. | `src/scripts/veaf/`, `doc/`, `test/lua/` | spike | ✅ |
| LUA-I18N-002 | Implement `veaf.t(key, ...)` + the catalog + `veaf.language` wiring (`lua_config_generator` emits it from `mission.yaml`, default `"fr"`); fallbacks (lang → FR → key). luaunit tests. | `src/scripts/veaf/veaf.lua` (or `veafI18n.lua`), `veaf_libs/lua_config_generator.py`, `src/defaults/mission-folder/mission.yaml`, `test/lua/`, `test/python/` | feat | ✅ |
| LUA-I18N-003 | Migrate the **pilot-feedback** messages (UXPILOT-FEEDBACK: `veaf.reportToPilot` call sites in `veafMarkers` / `veafSpawnCore`) to `veaf.t`, with FR + EN entries — the first real consumer. | `src/scripts/veaf/veafMarkers.lua`, `src/scripts/veaf/veafSpawnCore.lua`, catalog, `test/lua/` | feat | ✅ |
| LUA-I18N-004 | Migrate the hardcoded in-game messages to `veaf.t` (FR + EN). Done across all modules with pilot-facing prose: spawn, combat zone/mission, missile guardian, CAS, transport (incl. help), move, radio, security, skynet helper, named points, ground AI, carrier ops, sanctuary enforcement, shortcuts, weather fog, assets. Logs stay English; only on-screen text localized. **Deliberately out of scope**: mission-configurable templates (Air-Waves, QRA, Ground-AI start/stop, Combat-Zone events, Sanctuary warnings — user-overridable, not catalog material) and large data reports (weather/ATC METAR report, transport nav report, carrier list/recovery status). Localizing those = a separate lot if ever wanted. | `src/scripts/veaf/*.lua`, catalog, `test/lua/` | feat | ✅ |

---

## Lot QUALITY-GATE — Erode mypy exclusions and ratchet the coverage gate

**Goal**: Two quality guards are advertised but neutralized where it matters. `pyproject.toml:102-120` sets `ignore_errors = true` for **every large worker** (`aircrafts_injector_worker`, `mission_builder_worker`, `mission_converter_worker`, `presets_*`, `waypoints_*`, `weather_*`), so mypy only type-checks already-clean small files — exactly where the SECREV defects did *not* hide. Line coverage is **16%** with `--cov-fail-under=15`, so the gate protects nothing. Turn both into a debt eroded lot-by-lot rather than a single big-bang. Supersedes the archived single-shot attempt (`backlog-archive.md` "Retirer `ignore_errors`…").

**Branch**: `chore/quality-gate` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| QUALITY-001 | Remove `ignore_errors` for the simplest still-excluded workers (start with `presets_injector_worker`, `waypoints_injector_worker`), fix the surfaced type errors, leave the rest. | `pyproject.toml`, touched workers, `test/python/` | chore | ✅ |
| QUALITY-002 | Document the ratchet policy in `CLAUDE.md` §3: every lot that substantially touches an excluded worker drops its `ignore_errors` entry as part of its Definition of Done; every lot that adds tests bumps `--cov-fail-under` so the gate never sits more than ~2 pts below actual coverage. | `CLAUDE.md`, `pyproject.toml` | chore | ✅ |

> Cross-cutting reminder: the worker-reopening lots (MODULES-UNIFY, AIRCRAFT-INJECT, CONVERT-FIDELITY, SECREV) should each drop the touched worker's mypy exclusion as part of their own work, so this lot only mops up the remainder. **`CLAUDE.md` §3 (Quality Ratchet Policy) is the single source of truth** for this rule; the notes here and in `ROADMAP.md` §2 are summaries.

---

## Lot SPAWN-REFACTOR — Characterize then de-duplicate the spawn subsystem

**Goal**: The spawn subsystem — `veafSpawnParser` (656 l., 47 parameter rules), `veafSpawnAircraft` (1486 l.), `veafSpawnGround` (1034 l.) — carries heavy copy-paste (repeated parameter validation, ~15-line debug-log blocks duplicated verbatim, 30+ repetitive default-option blocks) and has **zero luaunit tests** despite being the most complex, most pilot-facing code. Lock current behaviour with characterization tests **first**, then de-duplicate safely.

> **Coordination**: TODO0609-SPAWN-EXTERNALIZE and TODO0609-AIRCRAFT-INJECT reopen these same files. De-duplicate **there**, within those lots' scope, rather than twice — this lot may be folded into SPAWN-EXTERNALIZE once -001 lands. Respect `CLAUDE.md` §2 RULE N°1 (no refactor outside a lot already touching the file).

**Branch**: `refactor/spawn-subsystem` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| SPAWN-REFACTOR-001 | Characterization tests for `veafSpawnParser.markTextAnalysis`: 41 marker variants (rejects/typos/missing values, every command + defaults, air-role defaults, parameter parsing), captured against the live parser and asserting only deterministic fields (math.random defaults left unasserted). Locks behaviour before any dedup; unblocks UXPILOT-003. | `test/lua/test_veafSpawnParser.lua` | feat | ✅ |
| SPAWN-REFACTOR-002 | Extract a spawn-type **descriptor table** (`{type → {defaults, validators}}`) consumed by the parser, and a shared `VeafSpawner` base for the duplicated validation/debug blocks. Only within the scope of a lot already touching these files. Done as SPAWN-EXTERNALIZE-005: `CommandDescriptors` (per-command defaults) + `ParameterRules` (keyword parsing) tables, and centralized the security preamble in `registerCommandHandler`/dispatch. | `src/scripts/veaf/veafSpawnParser.lua`, `veafSpawnAircraft.lua`, `veafSpawnGround.lua`, `veafSpawnCore.lua`, `test/lua/` | refactor | ✅ |

---

## Lot IMC-FEEDBACK-2 — Second-round IMC-Day user feedback (6.4.0)

**Goal**: Address the second round of IMC-Day migration field feedback (`tests-mct6-imcday(3).md`, tested with v6.4.0 on 2026-06-10; the first round, 2026-05-31 / v6.2.0, was handled by the archived Lot 26 IMC-FEEDBACK). Items already fixed in `develop-v6` carry no ticket here: Skynet listed twice and QRA/`external_modules:` scattering are solved by TODO0609-MODULES-UNIFY (ships with the next release). The `spawnables.yaml`/`templates.yaml` confusion repros were handed to **TODO0609-AIRCRAFT-INJECT**, and the trigger-migration repros to **TODO0609-TRIGGERS-VERIFY** (see there).

**Branch**: `fix/imc-feedback-2` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| IMC2-001 | **`prepare` broken in the packaged exe**: `prepare` resolves the default files relative to `__file__` ([prepare.py:39-46](src/python/veaf-tools/veaf_tools/commands/prepare.py)), which points inside the PyInstaller temp dir (`Temp\_MEI…`) in a frozen exe → `Default files not found`. The defaults are NOT meant to be bundled in the exe — they ship in `published.zip` and are installed by the updater into `<mission>/published/`. Fix: resolve the defaults from the **target mission folder** (`<mission-folder>/published/src/defaults/mission-folder`, the updater's install location — same as the build worker), with the dev-checkout path as fallback. | `veaf_tools/commands/prepare.py`, `test/python/` | fix | ✅ |
| IMC2-002 | **Drop the useless READMEs**: the README copied into the mission folder has dead relative links and overwrites the user's own README. Per David: remove all useless READMEs entirely (the online documentation is the single source) — stop shipping/copying any README into the mission folder, whether via the defaults scaffold or the updater. Never overwrite a user file. | `veaf-tools-updater.py`, `src/defaults/mission-folder/`, `test/python/` | fix | ✅ |
| IMC2-003 | **`custom_scripts` load trigger not created** (reported on 6.4.0). **Root cause found** (Flogas mission): the scripts were declared in a v5 custom loader (`src/scripts/VeafDynamicLoader.lua`) that `convert-v5` does not parse, so they were never registered as `custom_scripts:` → no trigger → missing F10 menu. **Resolution** (David): not a generation bug and not worth a brittle per-loader parser — resolved by **CONVERT-CUSTOM-LOADER-HINT** (generic detection + guidance to the v6 `custom_scripts:` mechanism). | `mission_builder/mission_builder_worker.py`, `test/python/` | fix | ✅ |
| IMC2-004 | **`veafAssets.respawn` fails with MIST errors** (`T2-Shell-1 not found in mist.DBs.MEgroupsByName`): respawn relies on `mist.respawnGroup` (`veafAssets.lua:157`), which reads `mist.DBs.MEgroupsByName` — only groups **placed in the Mission Editor** (present in the base `.miz` at load). **Decision (David)**: assets are, by design, ME-placed groups put in the mission by the mission maker — keep the runtime behaviour as-is. Instead: (a) **document clearly** that ASSET/QRA/… groups must exist in the mission (and the ASSETS→MIST dependency); (b) add a **build-time validation**: any group declared in a config (ASSETS, QRA, …) that is **not present in the mission** raises a clear localized (i18n) warning at build. | `mission_builder/`, `veaf_libs/lua_config_generator.py`, locales, `doc/`, `test/python/` | feat | ✅ |
| IMC2-004b | **(part of -004) Generic "declared group not in mission" build validator**: a reusable check that collects the group names referenced by each config section (ASSETS, QRA, and any other section that points at mission groups) and warns (i18n) for each missing one. | `mission_builder/`, locales, `test/python/` | feat | ✅ |
| IMC2-005 | **Fog modification does not work in-game**: `veafWeather.lua` already uses the modern DCS fog API (`world.weather.setFogThickness`/`setFogAnimation`). **Resolved**: verified working on **Caucasus** (David, 6.4.26). Not a VEAF bug — fog support is **map/DCS-version dependent**; documented in `veafWeather.md` / `.en.md`. No code change. | `doc/mission-maker/scripts/veafWeather*.md` | fix | ✅ |
| IMC2-006 | **Scaffold `.gitignore` gaps**: add exclusions for built `.miz` files and the `/missions/` output folder; check whether `/build/` is still produced and drop it if not. The file is `NEVER_OVERWRITE`, so existing users must apply the change manually — say so in the changelog entry. | `src/defaults/mission-folder/.gitignore`, `test/python/` | fix | ✅ |
| IMC2-007 | **Keep the default `mission.yaml` in lockstep with `convert-v5` output** + per-module descriptive comments. Per David: the defaults `mission.yaml` must stay strongly aligned with what `convert-v5` generates — every relevant element `convert-v5` emits (comments, config blocks) must also appear in the default template. Add individual per-module description comments (category headers already exist), and decide WEATHERMARK's default (reported useless — default `false` or drop from template). **Process**: whenever the `convert-v5`/`mission.yaml` generation changes, update `defaults/mission-folder/mission.yaml` in the same lot (now noted in CLAUDE.md §9). | `src/defaults/mission-folder/mission.yaml`, `mission_builder/v5_converter.py`, `veaf_libs/lua_config_generator.py`, `doc/MISSION_YAML_REFERENCE*.md` | feat | ✅ |
| IMC2-008 | **Dynamic loading not controllable from `mission.yaml`/profiles**: it is a build-time flag only, so `profiles:` (TEST/SERVER) cannot switch it — exactly what the feedback asks for ("des profils de build… aussi pour les dynamic loadings"). Add a YAML key (e.g. `build.dynamic_loading`) overridable per profile; document it in the Build Profiles doc to fix discoverability ("ça existe peut-être mais je n'ai pas compris comment ça fonctionne"). | `veaf_tools/commands/build.py`, `veaf_libs/build_profiles.py`, `doc/MISSION_YAML_REFERENCE*.md`, `test/python/` | feat | ✅ |

---
