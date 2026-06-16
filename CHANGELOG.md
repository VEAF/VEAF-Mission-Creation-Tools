# Changelog

All notable changes to VEAF Mission Creation Tools are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Internal
- **Lua coverage gate + `veafUnits` backfill** (LUA-COVERAGE, wave 1). `test-lua` gained a `--cov-fail-under` option that fails the run when total luacov coverage drops below the floor; a new `lua-coverage` CI job enforces a **67 %** floor (ratchet — only ever goes up). Backfilled `veafUnits.lua` from 20 % to 93 % (33 new tests covering `placeGroup`/`processGroup` geometry and friends), lifting total Lua coverage to 69.7 %. Modules still around ~50 % (`Sanctuary`, `CombatMission`, `Skynet*`, `Weather`, …) are left for later waves
- **mypy `ignore_errors` debt fully eroded** (QUALITY-GATE-FINISH). The six remaining application workers under the mypy `ignore_errors` override (`mission_converter_worker`, `mission_extractor_worker`, `waypoints_manager`, `weather_injector`'s `lua_converter` / `dcs_weather_converter` / `weather_injector_worker`) are now type-checked. Four had no errors; the seven surfaced errors were fixed without behaviour change (annotate `config: dict[str, Any]` in the weather lua-converter; drop redundant `: Path` re-annotations and rename a shadowed loop variable in the extractor). Only the bundled third-party `luadata` library stays excluded. The whole `src/python/veaf-tools` tree now passes `mypy` with no per-module opt-outs

### Fixed
- **`convert-v5` no longer produces an unparseable `mission.yaml` when a QRA was disabled in v5** (FIX-CONVERT-V5-INVALID-YAML). A QRA defined with `start = false` made the converter emit `start: false` at the `definitions:` sequence level (6-space indent) instead of inside its `- name:` list item (8 spaces), because the comment translation hard-coded the indentation. DCS/YAML then rejected the file (`expected <block end>, but found '?'`, e.g. around line 212). The flag is now emitted with the same field indent as every other QRA field, and the FR/EN translation holds only the comment. Verified end-to-end on the reporting mission (Training-Syrie now parses); regression tests assert the generated QRA block always parses
- **The generated `_version.py` no longer shows up as permanently "modified"** (FIX-VERSION-PY-EOL). `veaf-build` wrote `veaf_tools/_version.py` in text mode, so on Windows Python translated `\n` to `\r\n`; the git-tracked stub is normalized to LF (`.gitattributes` `eol=lf`), so every build left the working tree dirty with a CRLF-only, content-less diff. `_write_version_py` / `_restore_version_py` now pass `newline="\n"`. The same latent issue in `radio_specs_updater` (the tracked `dcs-radio-specs.yaml` / `.md` artifacts) was fixed too, aligning it with the other `dcs_data` generators that already force LF

### Changed
- **`TUM` (The Universal Mission) is now opt-in and auto-initialized** (TUM-AUTOINIT). TUM imposes a mission-design contract (BLUFOR/REDFOR territory zones, each owning an airbase) and aborts at start-up otherwise, so it must never start on its own. It is now the only community script that is **off by default**: a vanilla mission, a freshly v5-converted mission, or a `modules:` block that omits `TUM` all leave it disabled — only an explicit `TUM: true` enables it (the other community scripts stay opt-out, active unless set to `false`). Previously TUM followed the opt-out default, so it was enabled — and `TUM.initialize()` emitted — for missions that never set it up, producing the `Coalition red has no territory zones…` runtime error. When `TUM: true`, the build now calls `TUM.initialize()` automatically at start-up, so no manual `mission-script.lua` wiring is needed. `convert-v5` emits `TUM: false` even when the TUM file is detected

### Documentation
- **Documented the `TUM` "no territory zones / no airfields" start-up error** (INVESTIGATE-REDFOR-ZONES spike). The runtime error `Coalition red has no territory zones and/or controls no airfields…` comes from the third-party **The Universal Mission (TUM)** community script, not from VEAF: it is an expected TUM mission-design prerequisite (`BLUFOR…`/`REDFOR…` trigger zones, each owning an airbase). `MISSION_YAML_REFERENCE` (FR/EN) now documents this next to the `TUM` module id. Full analysis journaled in `backlog.md`. No code change

## [6.5.0] — 2026-06-13

### Changed
- **`SHORTCUTS` enabled by default** in the shipped `mission.yaml`, so the built-in spawn aliases (`-shilka`, `-sa2`, …) work out of the box. The default previously left `SHORTCUTS` commented as "needs a list", which was misleading — a `shortcuts:` list is only needed to add *custom* aliases on top of the built-in ones
- **`CASMISSION` and `TRANSPORTMISSION` enabled by default**. Both are marker-driven (`_cas` / `_transport`), need no configuration and impose nothing, so they join the default baseline. Default policy: a module ships ON when it is useful to everyone, needs no config block and changes nothing on its own; it stays OFF when it requires a config block (ASSETS/SANCTUARY/COMBATMISSION/COMBATZONE/QRA/AIRWAVES), changes gameplay (MISSILEGUARDIAN), is carrier-specific, or is a community script
- **Marker-command coalition handling clarified** (COALITION-REFACTOR). The scattered, hard-to-follow coalition inversion (`(event.coalition == 1) and 2 or 1`, duplicated in spawn / CAS / shortcuts) is replaced by two intent-revealing helpers in `veaf.lua`: `veaf.getOppositeCoalition(side)` (the default side of units spawned from a marker — markers spawn threats for the opposing side) and `veaf.getRequesterCoalition(event)` (the coalition that issued the command, for pilot feedback). This separates two concepts that were conflated. **Fix**: the "unknown spawn parameter" hint was addressed to the *spawn* side (opposite the pilot), so the pilot who placed the marker never saw it; it now goes to the requester (or all coalitions when unknown). Same spawn behaviour as before, but explicit and consistent.

### Fixed
- **An unknown spawn-marker parameter now aborts the command** instead of spawning anyway. A typo such as `_spawn unit, name shilka, headng 90` previously warned about `headng` but still spawned the unit; it now reports the hint (with a "did you mean …?" suggestion) and performs **no spawn**, leaving the marker in place so the pilot can fix the typo. Recognized parameter keys are derived from the spawn parameter rules, so a flagged key is always one that would otherwise have been silently ignored
- **Radio presets no longer make a mission unsaveable** (presets injector). When a resolved preset (e.g. a catch-all `all` UHF/VHF/FM plan) was only *partially* compatible with an aircraft — some channels in range, some not (a P-51D/TF-51D/P-47D capped at ~200 MHz, an SA342 Gazelle at ~88 MHz, both fed a 243 MHz UHF Guard channel) — the whole preset was injected, including the out-of-range channels, and the DCS Mission Editor refused to save ("Invalid frequency 243 MHz"). Out-of-range channels are now dropped per aircraft (the in-range ones are kept), so the mission always saves. A fully incompatible aircraft (e.g. Yak-52, sub-MHz ARK-15M) still keeps its original radio untouched, as before. Also added the missing MiG-15bis / MiG-15bis_FC radio spec (HF RSI-6K, 3.75-5 MHz) so the MiG-15 is correctly detected as incompatible with modern UHF/VHF presets (it was absent from the spec table, so a 243 MHz channel slipped through)
- **Dynamic-Slot warehouse templates now bind in-game** (DYNSLOT-WAREHOUSE). The warehouse wiring wrote each dynamic-slot aircraft entry **flat** under `aircrafts` (`aircrafts[<type>]`), but DCS nests them by category — `aircrafts.helicopters[<type>]` / `aircrafts.planes[<type>]`. A flat entry is silently ignored, so `dynamicSpawn`/fuel/munitions applied but the `linkDynTempl` template link never bound (the airbase fell back to default dynamic slots). Entries are now placed under the correct sub-table, classified via the committed DCS units database (`category`), with the mission's dynamic-spawn templates as a fallback for mod aircraft
- **`_spawn unit` success message is now localized** (i18n follow-up). The single-unit spawn feedback (`veafSpawn.spawnUnit`) and its JTAC variant were left as hardcoded English literals during LUA-I18N-004; they now go through `veaf.t` with new FR + EN catalog entries (`spawn.unit_spawned`, `spawn.jtac_spawned`), so `_spawn unit, name <alias>` reports in the mission language like `_spawn group` already did
- **Dynamic mode no longer initializes the VEAF modules twice**. The dynamic mission-loading trigger loaded `veaf-config.lua` explicitly *and* via `veafDynamicConfig.lua` (which already heads its `scriptsToLoad` list with it), so every module's `initialize()` ran twice — e.g. `veafCommands` registered its central marker-dispatch handler twice, making a single F10 marker command (such as `_spawn group, name sa2`) execute twice. The redundant explicit load was removed from the dynamic trigrule; `veafDynamicConfig.lua` remains the single entry point and loads `veaf-config.lua` first. Static mode was unaffected
- **`_spawn` / QRA are now initialized in dynamic mode**. The generated `veaf-config.lua` called `veafSpawnCore.initialize()` / `veafQraCore.initialize()` (nil globals) instead of `veafSpawn.initialize()` / `veafQraManager.initialize()`: the config generator derived the module variable from the file name, but a proxy module's table differs from its file (e.g. `veafSpawnCore.lua` defines `veafSpawn`). The `_spawn` marker handler was therefore never registered. The generator now maps each module id to its real table name (read from `<table>.Id`)
- **Dynamic mission loading no longer recurses infinitely**. The generated `veafDynamicConfig.lua` (the dynamic loader) listed itself among the scripts it loads, so at mission start it re-loaded itself endlessly. The loader is now excluded from the list it iterates
- **Split spawn/QRA proxies load under DCS dynamic `loadfile`**. `veafSpawn.lua` / `veafQraManager.lua` resolve their own directory to `dofile` their split parts; the detection assumed a `@`-prefixed chunk source, which DCS omits under dynamic `loadfile`, so the proxies aborted and cascaded `nil` errors (`veafRemote`/`veafUnits`). Directory detection now handles a source with or without the leading `@`

### Changed
- **Default `mission.yaml` documents the newest pipeline steps**: the commented `pipeline:` block (shipped default + the `convert-v5`/generated template) now also lists `warehouses` (Dynamic-Slot warehouses, `src/warehouses.yaml`) and `spawn_data` (always-on spawn-database injection, extended by `src/spawn-groups.yaml`), so mission makers discover them. No behaviour change — both steps and their default files already shipped; only the inline documentation was stale
- **In-game default language now follows the tools' language** (LUA-I18N). When `mission.yaml` does not set `mission.language`, the build emits `veaf.config.language` from the tools' resolved language (`--lang` > `VEAF_LANG` > user config > OS locale > `en`) instead of a hard-coded `fr`. So a mission built by a French maker defaults to French in-game and others to their locale; `mission.language` still overrides, and the Lua-side `veaf.I18N_DEFAULT_LANGUAGE = "fr"` remains only as the ultimate runtime fallback. No new CLI surface — the existing global `veaf-tools --lang` already drives it

### Added
- **In-game messages localized across the framework** (LUA-I18N-004, FR + EN). Building on the i18n layer, the pilot-facing messages of the VEAF modules are routed through `veaf.t` with FR + EN catalog entries: spawn (unit/group/cargo/static/teleport/convoy/IADS), combat zones / combat missions / missile guardians (shared `entity.*` activation states), CAS and transport mission calls (incl. the transport help), ground/tanker/AFAC moves, radio, security (password/lockdown), skynet helper, named points, ground AI (fire orders), carrier operations (errors/help/stop), sanctuary enforcement, shortcuts (alias errors), weather fog, and assets status/help. Logs stay in English; only the on-screen text is localized. **Deliberately out of scope** (documented): mission-**configurable** message templates (Air-Waves, QRA, Ground-AI start/stop, Combat-Zone events, Sanctuary warnings — these are user-overridable, not catalog material) and large **data reports** (weather/ATC METAR-style report, transport navigation report, carrier list/recovery status) — localizing those would be a separate lot
- **In-game message localization (Lua runtime i18n)** (LUA-I18N-001/002/003, FR default + EN). The Lua scripts had no i18n — every pilot-facing message was a hardcoded English literal. New `veaf.t(key, ...)` lookup (in `veaf.lua`) over a `veaf.i18nCatalog` catalog (new `veafI18n.lua` module), with `string.format` interpolation and fallback (requested language → French → the key). The active language is `veaf.config.language`, emitted into `veaf-config.lua` from `mission.yaml`'s `mission.language` (default `fr`; mission-global, since DCS exposes no per-pilot language). First consumers migrated: the UXPILOT pilot-feedback messages (marker-command failure, unknown spawn parameter + "did you mean" hint) now have FR + EN entries. The remaining `outText` literals are migrated module-by-module over time (LUA-I18N-004). See ADR 0006

### Changed
- **Spawn subsystem de-duplicated** (SPAWN-EXTERNALIZE-005 / SPAWN-REFACTOR-002), iso-functional and covered by the characterization tests. Three repetitive blocks became data-driven: (1) the per-command security preamble (`if not (bypassSecurity or veafSecurity.checkSecurity_Lx(...)) then return nil, nil, true end`, repeated in ~25 handlers) is now applied centrally by the dispatcher — `registerCommandHandler(key, security, fn)` declares the level (`L9`/`L1`/`MM`, or none for smoke/flare/signal); (2) the ~50-branch mark-text keyword parser (`if key:lower() == "…"`) is now a `veafSpawn.ParameterRules` descriptor list (the recognized-key set for typo hints is derived from it — single source of truth); (3) the command-detection if/elseif chain that seeds per-command defaults is now a `veafSpawn.CommandDescriptors` ordered list (first match wins). No behaviour change to `_spawn`/`_destroy`/`_teleport`/`_drawing`/`_mm` commands

### Added
- **Spawn database externalized to YAML** (SPAWN-EXTERNALIZE-002/003/004). `veafUnits.UnitsDatabase` / `GroupsDatabase` (the ~1450 lines of hand-coded `_spawn unit`/`_spawn group` data) are no longer literals in `veafUnits.lua`: they now live in a shipped `veaf_libs/data/veaf-units.yaml` (13 units, 78 groups), are rendered to Lua, and **injected into the `.miz` at mission build** (DCS can't parse YAML at runtime). The framework Lua now defaults the two tables to empty; a new always-on `spawn_data` build step embeds them after the framework bundle loads. A one-time parity oracle confirmed the generated Lua is semantically identical to the previous tables. Missions can extend or override the database with an optional `src/spawn-groups.yaml` (merged over the framework data — a shared alias replaces the framework entry; case-insensitive). Disable with `pipeline: { spawn_data: false }`. Ships a commented `src/spawn-groups.yaml` default. See `doc/PIPELINE_REFERENCE.*` and ADR 0005
- **Pilot feedback for marker commands** (UXPILOT-FEEDBACK). Mistyped or failing F10 marker commands are no longer silent: (1) the `veafMarkers` dispatch already wrapped handlers in `pcall` but only logged — it now also shows the placing coalition a short in-game message when a handler errors (the stack still goes to the DCS log); (2) a new `veaf.reportToPilot(message, duration, coalition)` helper (thin wrapper over `trigger.action.outText` / `outTextForCoalition`); (3) `veafSpawn` now warns the pilot about an **unknown spawn parameter** and suggests the nearest valid key (Levenshtein `veaf.nearestMatch`), e.g. `headng` → "did you mean 'heading'?"
- **Dynamic-Slot warehouse wiring** (`warehouses.yaml`, DYNSLOT-WAREHOUSE). A new build pipeline step configures DCS Dynamic Slots per coalition: it enables `dynamicSpawn` on the selected airbases, sets fuel/munitions and aircraft stock, and links each offered aircraft type to its `dynSpawnTemplate` group via `linkDynTempl` (the model providing loadout/livery/radio/route). Airbases are selected by **all-of-coalition** (default), by **name** (resolved via the airdrome table + mission theatre), or by **id**, with per-airport overrides. Runs after aircraft injection so the template groups exist. Ships a commented `src/warehouses.yaml` default (no-op until filled). See `doc/PIPELINE_REFERENCE.*`
- **Airdrome name→id table** (`veaf_libs/data/airdromes.yaml`, DYNSLOT-WAREHOUSE prerequisite). Maps, per theatre, an airfield display name to the numeric DCS airdrome id used as `airports[<id>]` in a mission's `warehouses`. Generated from a local DCS install's terrain `Beacons.lua` via `veaf-build update-dcs-data --airdromes --dcs-path <DCS>` (install-dependent, not CI-guarded). Resolver `veaf_libs.dcs_airdromes.airdrome_id_for_name(theatre, name)`. Ships 7 theatres / 194 airfields; beacon-less maps (Normandy) yield no entries (callers fall back to ids)

### Changed
- **DCS units database now comes from the datamine** (DCSDATA-008), retiring the in-DCS export (`dcsDataExport.lua`) as the source of `dcsUnits.lua` (the export stays for airbases/weapons). New two-stage pipeline: `veaf-build update-dcs-data --units` parses `Quaggles/dcs-lua-datamine` into a committed canonical `dcsUnits.yaml`, then renders `src/scripts/veaf/dcsUnits.lua` from it. The runtime schema is simplified — keyed by DCS type, with a single `kind` (`air`/`naval`/`infantry`/`vehicle`/`static`) replacing the four booleans — and `veafUnits` was updated accordingly (fast keyed lookup in `findDcsUnit`). Both artifacts are pure and CI-guarded (consistency + drift). Validated against the previous 833-unit file: 0 kind regressions, the 2 datamine-absent units carried over. Documented in `doc/developer/dcs-data.*`

### Added
- **`veaf-tools ask` — documentation chatbot in the CLI/TUI** (CHATBOT-CLI). Ask a question about the VEAF docs and get a grounded AI answer — the same assistant as the website chatbot. One-shot (`veaf-tools ask "how do I enable CTLD?"`) or an interactive REPL, plus a TUI entry « Ask the documentation ». **No API key and no setup**: the command proxies the question to the project's documentation Worker (which owns the Gemini key, runs the RAG and streams the answer), identifying itself with an `X-VEAF-Client: cli` header and bounded by the Worker's per-IP rate limit
- **Documentation chatbot — Gemini 429 handling** (DOC-CHATBOT-005): when the Gemini free-tier quota is hit, the docs chatbot now answers with the localized "too many requests, retry shortly" message instead of the generic "temporarily unavailable", on both the generation and embedding paths. Completes the chatbot lot (repo secrets set; the widget already ships to the versioned `mike` docs via `mkdocs.yml`)
- `build`: **automatic CTLD/CSAR sound packaging** (BUILD-COMMUNITY-SOUNDS-001). CTLD and CSAR play their sounds by filename at runtime, so the files must be in the mission's `l10n/DEFAULT/`. The tools now ship the canonical sounds (`beacon.ogg`, `beaconsilent.ogg`, `CSAR.ogg`, sourced upstream) under `src/scripts/community/sounds/` and, when CTLD or CSAR is enabled, inject the ones a mission is missing — **without overwriting** sounds the mission already provides. Nothing is injected when both modules are off. A required sound shipped by neither the tools nor the mission (e.g. `radiobeep.ogg`, the JTAC fallback beep, which upstream does not redistribute) is reported with a build warning so the mission maker can add it. No DCS trigger or `mapResource` entry is created — packaging the file in `l10n/DEFAULT/` is sufficient

### Fixed
- `build`: the legacy v5 **CTLD/CSAR sound-preload trigger** (an `out_sound` registering `beacon.ogg` / `beaconsilent.ogg` / `CSAR.ogg`…) is now dropped — along with its `mapResource` entries — when **both** CTLD and CSAR are disabled, instead of surviving as dead weight. It is left untouched when either module is enabled. Non-community sounds are never touched. Re-creating/packaging the trigger when a module is enabled is tracked separately (`BUILD-COMMUNITY-SOUNDS`) (TRIGGERS-VERIFY-004)

### Removed
- **WeatherMark community script retired**: its weather-report helpers were already replaced by `veafWeather` (the only remaining usage was a commented-out, deprecated `veaf.weatherReport` body). Removed `src/scripts/community/WeatherMark.lua`, the `weathermark` community-script entry, the dead `veaf.weatherReport` body, and the docs reference (WEATHERMARK-REMOVE-001)
- Removed the now-empty deprecated `veaf.weatherReport` stub entirely (no callers; superseded by `veafWeatherData.getWeatherString`) (WEATHERMARK-REMOVE-002)

### Added
- `TUM` now actually starts: when enabled, `veaf-config.lua` emits `if TUM then TUM.initialize() end` so TheUniversalMission is initialized at runtime (previously `TUM: true` loaded the script but never called `initialize()`) (TUM-INIT-001)
- `veaf-build` **auto-computes the release build number** when `--version` is omitted: it reads the project base (`X.Y.Z`) and the previous `published.zip` version — same base → increments the build number (`X.Y.Z.4`), different base or no `published.zip` → starts at `X.Y.Z.1`. `--version` still overrides (BUILD-AUTOVERSION-001)
- **Automatic mission-era detection**: when `mission.era` is not set in `mission.yaml`, `build` infers it (`WW2` / `COLD_WAR` / `MODERN`) from the base mission — a combined heuristic over the DCS mission **year** and a **WW2-era unit/aircraft-type** reference table (WW2 wins on the unit signal even at a modern default year). A manually-set `mission.era` always takes precedence (ERA-AUTODETECT-001/002)
- `convert-v5`: **commented-out v5 elements are no longer silently dropped** — a combat zone, asset, QRA, shortcut, etc. that was disabled with `--` in `missionConfig.lua` is now re-emitted at the end of `mission.yaml` as a fully-commented **"Commented-out v5 elements"** block, so you can re-enable it by uncommenting. Generic across every extractor (a de-commented re-extraction is diffed against the active config; pattern-based extraction ignores prose) (CONVERT-FIDELITY-001)
- `convert-v5`: the annotated report (`convert-v5-report.md`) now opens with an at-a-glance **Summary** — how many modules were migrated and how many items still need manual action (with the source line numbers) — so you see whether work remains without reading the full annotated config (CONVERT-FIDELITY-004)
- `mission.silence_atc_on_all_airbases` (default `true` in the template): emits `veaf.silenceAtcOnAllAirbases()`; `convert-v5` detects an active call in `missionConfig.lua` and preserves it (CONVERT-FIDELITY-003)
- TUI: the mission-folder prompts (`build`, `extract`, `convert-v5`, `prepare`) now show a hint clarifying the `.` default — `'.' = current folder → <absolute path>` (FR/EN) — so it's obvious which directory will be used (TUI-FOLDER-HINT-001)
- `build` / `mission.yaml`: **dynamic loading is now controllable from `mission.yaml` and profiles** via `build.dynamic_loading` (profile-overridable); the CLI flag becomes `--dynamic-mode` / `--no-dynamic-mode` and takes precedence. So a `TEST` profile can switch dynamic loading on without a CLI flag (IMC2-008)
- **Dynamic loading now works in both DEV and PROD** (FIX-DYNLOAD-PUBLISHED). Previously a dynamic build always emitted the DEV loader (`VeafDynamicLoader.lua`, which loads the *individual* `veaf/*.lua`), but a `published/` install only ships the concatenated **bundle** → runtime "no file" error. Now: **DEV** (`dev_mode: true`, `scripts_path` → a repo checkout) loads the individual scripts; **PROD** (`dev_mode: false`) loads the bundle `veaf/veaf-scripts.lua` from `scripts_path` (default `<mission>/published`, already in `published.zip` — no packaging change). In **both** modes the mission maker's `custom_scripts` are loaded from disk via a now-**generated** `src/scripts/veafDynamicConfig.lua` (mirrors the static load list; do not edit by hand). The build fails with a clear localized error if the framework loader is missing under `scripts_path`. Use case: keep scripts out of the `.miz`/`.trk` shared by players
- `build`: **guides users with a custom Lua script-loader toward the v6 way** (CONVERT-CUSTOM-LOADER-HINT, resolves IMC2-003). When an undeclared `src/scripts/*.lua` loads other scripts (`loadfile`/`dofile`/`require`/`a_do_script_file`), the build now explains that v6 replaces custom loaders with the `custom_scripts:` section of `mission.yaml` (each script loaded in order, with an auto-generated trigger), instead of the misleading "declare it in custom_scripts" advice. Generic heuristic — no per-loader parsing. This was the real cause of the "custom F10 menu missing" report: a v5 `VeafDynamicLoader.lua` (a mission-scripts loader, distinct from the v6 framework loader of the same name) registered the scripts and was not migrated
- `build`: **warns when a config-declared group is missing from the mission** (IMC2-004/004b). Groups referenced by `ASSETS` (asset name + `linked`), `QRA` (deploy lists), `cap_missions` and `combat_missions` must be placed in the Mission Editor; a missing one now raises a clear localized warning at build instead of failing silently at runtime (e.g. `veafAssets.respawn` → MiST "group not found"). The ASSETS→MiST dependency and the ME-placed-group requirement are documented
- **Aircraft groups are split into two independent pipeline steps** (ADR 0002, hard break): `spawnable_aircrafts` (→ `src/spawnables.yaml`, groups cloned at runtime by `veafSpawn`, identified by the `veafSpawn-` name prefix) and `dynamic_slot_templates` (→ `src/dynamic-slot-templates.yaml`, DCS Dynamic-Slot models, identified by `dynSpawnTemplate == true`). `extract-aircraft-groups` sorts each group by that criterion (the flag wins over the prefix), writing **both** files by default with a `--kind spawnable|dynamic-template` restriction; `convert-v5` produces both files from the v5 `settings.lua`. The legacy `.*[tT]emplate.*` name sort (which misrouted a spawnable named "… Template …") is dropped. Fixes three field issues from IMC-Day testing (6.4.0, see `tests-mct6-imcday §8`): (1) the orphan warning and the injected file no longer disagree — pre-v6 `aircraft-templates.yaml`/`templates.yaml` now produce a clear "ignored, use spawnables.yaml/dynamic-slot-templates.yaml" message; (2) recopying a deleted default is no longer silent; (3) `spawnables.yaml` is now actually injected (it was previously copied but consumed by no step). The TUI `extract`/`inject` aircraft prompts are updated to the new options (AIRCRAFT-INJECT-001..006)
- **Documentation chatbot (RAG)**: a free, bilingual assistant embedded in the docs site. A Cloudflare Worker (free tier) holds the Gemini key, enforces an Origin allow-list + per-IP rate-limit, and answers via retrieval-augmented generation — embedding the question (`gemini-embedding-001`), ranking the language's doc passages by cosine similarity **inside the Worker** against an embeddings index stored in KV (binary Float32 vectors, no paid vector DB), and streaming a grounded answer from `gemini-2.5-flash-lite`. A vanilla-JS resizable sidebar widget is wired into MkDocs (`mkdocs.yml`), and a CI workflow rebuilds the index when docs change. RAG was chosen over full-document injection, which hit the Gemini free-tier tokens-per-minute ceiling (~2 questions/min). Code under `poc/doc-chatbot/` + `doc/assets/chatbot/`; not yet shipped to the public site (needs CI secrets) (DOC-CHATBOT-001..004)
- **DCS country name→id table**: a generated `veaf_libs/data/dcs-countries.yaml` (92 countries, matched by canonical name, Mission Editor display name and short code) produced from the `Quaggles/dcs-lua-datamine` dump at a pinned ref — no DCS install needed. New `veaf_build.dcs_data` provider package and a `veaf_libs.dcs_countries.country_id_for_name()` lookup (DCSDATA-002)
- **`veaf-build update-dcs-data [--countries] [--radio] [--all]`**: one command to regenerate the datamine-sourced DCS reference data. The datamine is cloned at a **pinned** ref (`DATAMINE_REF`), making generation reproducible and the provenance ref is stamped into each artifact header (also fixes the previously non-reproducible `master`/`--depth=1` clone in the radio updater). `--all` regenerates only the **pure** `countries` artifact and skips the **hybrid** radio artifact (which carries manual `dcs_rejects_on_load` overlays + a bilingual doc), while `--radio` regenerates but warns those overlays must be re-applied. `update-radio-specs` is kept as a compat alias. New developer doc page *DCS data generators* (FR/EN) covering the datamine vs in-DCS-export sourcing strategies (DCSDATA-003/004)
- **CI freshness guards for DCS data**: a per-PR consistency workflow regenerates the **pure** country table against the pinned ref and fails if the committed file drifts (forgot `update-dcs-data` or hand-edited); a weekly drift-watcher workflow compares the upstream datamine HEAD to the pin and opens a PR bumping it + regenerating, for human review. Country-table generation now forces LF so the artifact is byte-identical across platforms (DCSDATA-005/006)
- **No more mandatory hand-placed blue+red ground groups** (DCSDATA-007b): the build now ensures each side coalition owns at least one unit. If a side has none, it injects a single **hidden** placeholder ground group (a real, roster-valid unit on the coalition bullseye, with a valid locked-ETA route) so DCS registers the side and the injectors don't skip groups. A unit-less synthetic country does **not** work — DCS purges it on save (verified in the Mission Editor, DCSDATA-007), so a real hidden unit is used. Mission makers can still place their own ground groups; the placeholder is only added when a side is empty. Bundled data: `mission_builder/data/placeholder_groups.json`
### Fixed
- **`inject-presets` no longer overwrites an aircraft's radio with incompatible frequencies** (`"Invalid frequency 243 MHz"`, mission won't save). The injector replaces a player aircraft's `Radio` with the preset resolved from `presets.yaml` (often via an `all` fallback); when every preset frequency is out of range for the aircraft's actual radio — e.g. a UHF/VHF preset resolved for a **Yak-52**, whose only radio is the sub-MHz ARK-15M — DCS rejected the save. The injector now skips a preset that is **wholly** out of range for a known aircraft and keeps its original radio (logged), using the existing `dcs-radio-specs.yaml` ranges. Partially-valid presets are still injected. (243 MHz is the legitimate UHF guard channel — valid for the F18/A-10; the bug was applying it to the Yak-52.) (FIX-PRESETS-RADIO-001)
- **`inject-waypoints` no longer produces routes DCS refuses to save** (`"Route has no waypoints with locked time!"`). A flight plan from `waypoints.yaml` (matched by aircraft type, so a catch-all plan rewrites every player slot) rebuilt each route with `ETA_locked=false` on every waypoint; DCS then rejected the save on each affected group. The injector now locks the first waypoint when the flight plan locked none, mirroring DCS. *(The separate `"Invalid frequency 243 MHz"` error is mission config — `presets.yaml` presets the reserved UHF guard frequency.)* (FIX-WP-ETA-001)
- **`inject-aircrafts` no longer produces a `.miz` that crashes the DCS Mission Editor on load** (`me_mission.lua:512`, `fixCountriesNames` → `attempt to index field '?' (a nil value)`). When `mission.yaml` injects aircraft into a country absent from the source mission (e.g. French spawnables in a USA/Ukraine-only `.miz`), the injector created the country **without** a `country.id`, which DCS dereferences as nil on load. Country-id resolution is now systematic — an id already present in the mission wins, else it is looked up in the generated DCS country table, else the build fails loudly — so a country is never emitted without an id. Completes the partial `bc37be3` fix (which only recovered an id when the country existed in another coalition) (DCSDATA-001)
### Changed
- **Faster `.miz`/Lua parsing** (PERF-LUADATA-PARSER): the pure-Python `luadata` parser (introduced by SECREV-001 to remove code execution) was slow on large missions. Two fixes — (1) it no longer re-sorts and rescans the whole entry list on every table append (`O(n²·log n)` → `O(n)` amortised, crippling on big DCS arrays like route points), and (2) it skips runs of insignificant whitespace/indentation at C speed instead of one byte per iteration. `read_miz` on a real 8.9 MB mission dropped from **0.86 s to 0.33 s (~2.6×)**; the whole build benefits. Parsing output is unchanged (array/sparse-key ordering, whitespace-insensitivity guarded by tests)
- `convert-v5` radio presets: **bespoke per-aircraft radio layouts are now reproduced iso-functionally** instead of being flattened to a shared preset (ADR 0003). When a v5 `["Radio"]` table is non-standard — channel rotation (Mi-24P channel 0 → preset #20), leading dummy / hardcoded specials / per-channel AM/FM modulations (AJS37), or extra radios — `convert-v5` emits a dedicated `{coalition}_{aircraft}` preset that maps each channel to its exact frequency (resolving `radioPresets*` tokens, keeping hardcoded literals) plus its modulation flag. Standard 1:1 layouts keep the lightweight shared assignment. `RadioDefinition.to_dict()` re-enables the `modulations` table so the AM/FM selection round-trips (PRESETS-FIDELITY-001)
- Quality ratchet (PRESETS-FIDELITY-001): dropped `presets_injector.presets_manager` from the mypy `ignore_errors` list and fixed the surfaced type errors; raised the coverage gate (`--cov-fail-under`) from 64 to 65 to track actual coverage
- Quality ratchet (QUALITY-001): dropped `presets_injector.presets_injector_worker` and `waypoints_injector.waypoints_injector_worker` from the mypy `ignore_errors` list and fixed the surfaced type errors (route/output-data annotations, `unit_type` `None` → `"all"` coalesce)
- Docs: audited the `defaults/mission-folder/` scaffold — every shipped file is consumed at first build, nothing dead (the old `presets.md` / `README-versions.md` are already gone). Corrected the `mission-maker/GUIDE` project-layout tree (FR/EN) to list every default (`options`, `versions.yaml`, `templates.yaml`, `veafDynamicConfig.lua`, `.gitignore`) with its role (DEFAULTS-AUDIT-001)
- Docs: documented the static-vs-dynamic VEAF script loading flow and clarified that `VeafDynamicLoader.lua` (framework layer) and `veafDynamicConfig.lua` (mission layer) are complementary, not duplicates — neither is obsolete (new [ADR 0004](docs/adr/0004-dynamic-script-loading.md), DYNLOAD-CLARIFY-001). ADR 0004 also records the origin of the mission-scripts loader ([VEAF-mission-converter#17](https://github.com/VEAF/VEAF-mission-converter/issues/17)) and the naming history behind the two near-identical filenames
- Quality ratchet (AIRCRAFT-INJECT): dropped `aircrafts_injector.aircrafts_injector_worker` from the mypy `ignore_errors` list and fixed the surfaced type errors; raised the coverage gate (`--cov-fail-under`) from 65 to 66. Removed the now-dead `lua_module` branch of the defaults-copy logic (every default now maps to a pipeline step)
- Default `mission.yaml` template realigned with the build/convert-v5 output (IMC2-007): the `pipeline:` section uses the split `spawnable_aircrafts` / `dynamic_slot_templates` steps, a `build:` section documents `dev_mode`/`scripts_path`/`dynamic_loading`, and `WEATHERMARK` defaults to `false` (reported as rarely useful). `convert-v5` emits the matching `build.dynamic_loading` comment. CLAUDE.md §9 adds a "defaults lockstep" rule to keep the template aligned with generation
- **Default `mission.yaml` now ships an active `modules:` block** instead of an all-commented one (FIX-DEFAULT-MODULES-ACTIVE). Previously a freshly-scaffolded mission had every module commented out → no VEAF F10 menu at all. The default now activates a baseline mirroring `convert-v5`: mandatory infrastructure + `SECURITY`, `RADIO`, `GROUNDAI`, `SPAWN`, `NAMEDPOINTS`, `MOVE`, `GRASS`, `WEATHER`, `REMOTE`, `AIRBASES`, `INTERPRETER`; community scripts (`CTLD`, `SKYNET`, …) `false`; config-requiring modules (`ASSETS`, `QRA`, `SHORTCUTS`, combat, …) shown as commented examples to uncomment
- **MiST is now mandatory**: it is a hard dependency of the VEAF scripts, so the build **always injects it** regardless of the `modules:` entry (an explicit `MIST: false` is ignored with a warning). The default `mission.yaml` lists `MIST:` in the mandatory infrastructure block (FIX-DEFAULTS-MODULES)
- `WEATHERMARK` removed from the default `mission.yaml` (the script is being retired; full removal tracked in WEATHERMARK-REMOVE)
- `convert-v5`: a fully-migrated `if veafXxx then … end` init block is now commented out **in its entirety** (not just the `initialize()` line), so any non-migrated custom code left in `missionConfig.lua` visually stands out (CONVERT-FIDELITY-002)
- **`mission.yaml` `modules:` is now the single source of truth** (hard break, pre-release — see ADR 0001). Skynet, CTLD, CSAR and QRA are configured under their `modules:` entry instead of the removed `external_modules:` / `qra:` sections: `modules.SKYNET` (flags), `modules.CTLD` / `modules.CSAR` (with a `settings:` sub-block for `ctld.xxx` / `csar.xxx` pairs), `modules.QRA` (`silence_all` + `definitions:`). The default template and the generated mission.yaml emit the unified shape; `convert-v5` produces it directly and now extracts CTLD/CSAR settings from `missionConfig.lua`. Docs (`MISSION_YAML_REFERENCE*`, migration guides) updated (MODULES-UNIFY-001..005)
- **Semantic validation of the `modules:` block**: an unknown module key, a removed `external_modules:` / `qra:` section, a wrongly-typed value, or a bad `enabled` / `logLevel` now raise a localized error at build time; an unrecognized `init:` parameter emits a warning instead of being silently dropped (MODULES-UNIFY-006)

### Security
- **RCE fixed**: parsing a `.miz` file no longer executes embedded Lua. `luadata.unserialize()` ran `lua.execute()` on untrusted mission content via an unsandboxed lupa runtime; it now routes through the pure-Python `_unserialize()` state machine (no code execution). Output is proven byte-identical to the former path across every real `.miz` fixture; a malicious-payload test asserts no execution. Also fixes a parser fidelity bug (backslash + CRLF/CR Lua line-continuations are now collapsed to `\n`, matching DCS Windows briefing texts) (SECREV-001)
- **Time-expression eval removed**: the weather moment parser replaced `eval()` with an AST evaluator accepting only numeric literals and `+ - * / // %`; names, attribute access, calls and exponentiation (a huge-number DoS) are rejected (SECREV-003)
- **Archive hardening**: `.miz` and `published.zip` extraction now validate every member through `veaf_libs.safe_zip.safe_extract_all`, rejecting Zip-Slip paths (absolute or `..`-escaping) and capping entry count and total uncompressed size (zip bomb) (SECREV-004, SECREV-005)
- `veafSecurity`: stopped logging the cleartext password at debug level (SECREV-009)

### Fixed
- **A mission with no `mission.yaml` now builds with the VEAF config** (FIX-BUILD-COPY-DEFAULTS): when the user had deleted/never had a `mission.yaml`, the build resolved its config from the (absent) file **before** copying the default into the folder → no `veaf-config.lua` (no VEAF F10 menu) and wrong module/community toggles. The default `mission.yaml` is now copied **before** the config is read, so a fresh mission gets the active baseline
- **Waypoint injection no longer destroys a flight's takeoff** (which made taking a player slot show the DCS *"YOUR FLIGHT IS DELAYED TO START, PLEASE WAIT"* message and blocked the slot). The injector rebuilt each matched group's route from scratch with only the injected waypoints, wiping its `TakeOffParking`/`Landing` points. It now **appends** injected waypoints to the existing route and **replaces only a waypoint of the same name** in place, preserving the original departure (FIX-WAYPOINTS-INJECT-PRESERVE-ROUTE-001)
- **`build` crashed on a mission with an empty coalition side** (`AttributeError: 'dict' object has no attribute 'append'`): an empty DCS `country = {}` table deserializes to a dict (not a list), so injecting the hidden placeholder unit into an empty side failed. The country container is now coerced to a list first. Reproduced with a single-aircraft Caucasus mission (one populated side, the other empty) (FIX-EMPTY-COALITION-COUNTRY-001)
- **`convert-v5` lost tables containing `nil` values** (regression from SECREV-001): the pure-Python `luadata` parser never handled Lua `nil`, so any table with a `key = nil` entry — pervasive in v5 (`country = nil`, commented-out `["waypoints"]` blocks) — failed to parse (`Unserialize luadata failed … unexpected character`) and was silently dropped (e.g. the `settings` table of `waypointsSettings.lua`). `nil` values are now accepted and dropped per Lua semantics (the entry does not exist); no code execution is reintroduced (FIX-LUADATA-NIL-001)
- `prepare` **broken in the packaged exe** (IMC2-001): default files were resolved relative to `__file__` (a PyInstaller temp dir in the frozen exe) → `Default files not found`. They are now resolved from the target mission folder's `published/src/defaults/mission-folder` (where the updater installs them from `published.zip`), with the dev checkout as fallback
- The updater no longer **moves `README.md` into the mission folder** (IMC2-002): it had dead relative links and overwrote the user's own README. The online documentation is the single source; the README stays under `/published/`
- Scaffold `.gitignore` now excludes built `*.miz` files and the `/missions/` output folder, and drops the stale `/build/` entry (IMC2-006). Existing missions must apply this to their own `.gitignore` (it is `NEVER_OVERWRITE`)
- **Helicopter extraction data loss**: `aircrafts_injector` only captured the *last* helicopter group of each country because the match/capture block was dedented out of its loop; every helicopter group is now extracted (SECREV-002)
- `convert-v5` weather: zero-valued weather params are no longer silently dropped — 0 °C, 0 wind speed (calm), 0 wind direction (due North), 0 visibility and ground-level cloud base now survive conversion (truthiness guards replaced by `is not None`) (SECREV-006)
- Lua nil-deref crashes guarded: `veafCasMission.generateAirDefenseGroup` (nil group), `veafCarrierOperations.getAtcForCarrierOperations`/`stopCarrierOperations` (nil carrier/unit), `veafSpawnGround.spawnConvoy` (`size/2` on nil size) (SECREV-007)
- `veafAirWaves.addWave`: a plain array-of-strings wave now stores each group name instead of the whole parameter table (SECREV-008)
- `veafSecurity.isAuthenticated`: now falls back to the real `veaf.SecurityDisabled` flag instead of the never-assigned `veafSecurity.SecurityDisabled` (SECREV-009)
- `veafMove`: an empty mandatory group name is now rejected (`""` is truthy in Lua, so the old guard never fired) (SECREV-010)

### Changed
- Test coverage gate (`--cov-fail-under`) raised from 15 to 60 to track actual line coverage (~63%) after the SECREV regression tests, per the Quality Ratchet Policy
- `CLAUDE.md` §3: documented the **Quality Ratchet Policy** — every lot that substantially edits a mypy-excluded worker must drop its `ignore_errors` entry (and fix the surfaced type errors), and every lot that adds tests must bump `--cov-fail-under` to stay within ~2 points of actual coverage. The exclusions list and the coverage gate are now explicitly erode-only forms of debt
- CI: migrated GitHub Actions off the deprecated Node.js 20 runtime ahead of the forced 2026-06-16 migration. Bumped `actions/checkout@v4`→`@v5`, `actions/setup-python@v5`→`@v6`, `actions/upload-artifact@v4`→`@v6` (first major running on `node24`), and the third-party actions `JohnnyMorganz/stylua-action@v4`→`@v5`, `softprops/action-gh-release@v2`→`@v3`, `gitleaks/gitleaks-action@v2`→`@v3`. `snok/install-poetry@v1` is a composite action with no Node runtime and was left unchanged

---

## [6.4.0] — 2026-06-09

### Fixed
- `build`: a bare mission name (not a `.miz` file) now produces an **absolute** output path anchored in the mission folder. Previously the path stayed relative, so the weather step looked for the mission under `<folder>/src/` and aborted with `Base mission not found`. This surfaced through the TUI, whose mission.yaml-aware default now pre-fills the real mission name
- `mission_extractor`: `extract` no longer crashes with `KeyError: 1` — the script-file cleanup loop now accepts both the `(path, dest)` tuples returned by `get_veaf_script_files()`/`get_legacy_script_files()` and the dict descriptors returned by `get_community_script_files()` (regression from the COMM-001 refactor)
- `config_migrator`: `_lua_extract_string()` no longer absorbs quoted strings from chained Lua setters after `:setBriefing(…)` — search is now bounded to the matching closing parenthesis (regression from PR #390)
- `mission_builder_worker`: missing-files error now uses i18n keys (`builder.missing_files`, `builder.update_hint`) instead of hardcoded English; `spinner_context` for `dcs-bridge.lua` injection also uses `t("builder.inject_dcs_bridge")`; fatal error no longer calls `exit()` (raises via `logger.error` instead, giving a non-zero exit code)
- `paths.py`: `resolve_path` now raises `FileNotFoundError` instead of calling `exit(-1)` when a required path does not exist — makes the function testable and avoids `SystemExit(0)` on error
- `v5_converter`: removed dead `is None` branch inside `if mr.mission_export_path is not None:` (unreachable)

### Added
- TUI wizard: when a `mission.yaml` is present in the working directory, the mission-name prompts (`build`, `extract`, `inject-presets`, …) now propose its `mission.name` field as the default instead of the static `mission.miz`. Resolution precedence is: last saved preference > value derived from `mission.yaml` > static fallback
- docs: documentation overhaul (bilingual FR/EN) — pilot guide rewritten (deduplicated, accessible, jargon explained, `_auth` standardized); mission.yaml example updated to the unified `modules:` block; mermaid diagrams added (F10 radio menu, build pipeline, v5→v6 migration flow); screenshot placeholders added under `doc/assets/img/`; created the missing French `veafInterpreter` page; fixed broken `GUIDE.fr.md` links
- docs: French/English parity for the large reference docs — `LUA_API_REFERENCE.md` (all module sections brought to full depth: missing functions, parameters, and code examples translated), `TOOLS_REFERENCE.md` (troubleshooting, command reference, best practices, security, FAQ sections added), and `dcs-radio-specs.md` (header and critical-aircraft prose translated)
- `mission.yaml`: new `dcs_bridge` section to optionally inject `dcs-bridge.lua` as the first DO SCRIPT FILE trigger in the mission; `lua_path` is optional — when absent, the file is downloaded automatically from GitHub (`VEAF/VEAF-dcs-bridge`)
- `community_scripts:` section in `mission.yaml`: individually enable/disable community Lua scripts (MIST, CTLD, CSAR, etc.) — absent section keeps all scripts active
- `convert-v5`: generated `mission.yaml` now includes a `community_scripts:` section pre-populated from scripts detected in `published/src/scripts/community/`
- `inject-presets`: DCS aircraft radio frequency validation — preset frequencies are now checked against each aircraft's hardware specs at build time; invalid frequencies (e.g. 284 MHz on a MiG-19P or Gazelle M) emit a warning before DCS rejects them at mission load
- `doc/mission-maker/dcs-radio-specs.md`: human-readable reference table of valid radio frequency ranges for all 85 DCS player-flyable aircraft, sourced from [dcs-lua-datamine](https://github.com/Quaggles/dcs-lua-datamine)
- `scripts/extract_dcs_radio_specs.py`: standalone utility to regenerate `dcs-radio-specs.yaml` and the reference doc after a DCS patch
- Klogg highlight profile for DCS logs added to `tools/klogg/veaf.conf`; GUIDE.md and GUIDE.en.md updated to reference it
- i18n coverage: all log messages in `mission_builder_worker.py`, `aircrafts_injector_worker.py`, and `waypoints_manager.py` now use `t()` — no more hardcoded English strings; matching French translations added to `fr.json`; tests verify all `t()` keys exist in `en.json` and that `fr.json` covers every `en.json` key
- i18n: AST-based test (`TestI18nNoHardcodedStrings`) scans all Python source files for hardcoded English prose in `logger.*()`, `console.print()`, and `return` statements; `aircrafts_injector_worker.py` and `lua_config_generator.py` now fully i18n-clean; remaining files listed in `_TODO_EXEMPTIONS` for progressive cleanup
- i18n: 90 additional hardcoded English strings replaced by `t()` calls across 24 source files (`mission_builder_worker.py`, `mission_extractor_worker.py`, `mission_constants.py`, `radio_frequency_validator.py`, `veaf-tools-updater.py`, `build_profiles.py`, `paths.py`, `tui.py`, all `veaf_tools/commands/*.py`, `waypoints_injector_worker.py`, `waypoints_manager.py`, `weather_injector/**/*.py`); `_TODO_EXEMPTIONS` emptied; Rich markup filter added to scanner `_has_prose`; all new keys added to `en.json` and `fr.json`

### Changed
- `veaf-tools-updater` and `veaf-build` now adopt the decluttered output model too: the transient status line is cleared at program exit (no lingering line), and the updater's outcome lines ("already up to date", "successfully updated to vX") are now permanent. Standalone `veaf-tools` commands already inherit the model.
- CLI output is now decluttered: low-importance progress messages (`logger.info`) are shown on a single overwriting status line in interactive terminals instead of scrolling endlessly; permanent technical lines (`logger.tech`) and chapter headers (`logger.step`) stay on screen. Spinner/progress "done" lines no longer persist. `--verbose` (and non-interactive/piped output) restores the classic line-by-line display; the full log file is unaffected and still records every message. The `build` command adopts the new chapter/technical classification: each pipeline step shows an animated spinner during its slow operations (reading/writing the `.miz`, validating), the weather step shows a progress bar over the variants it creates, and the aircraft-groups injection is now visible during a build (was silent). Every pipeline step ends with a concise persistent result line (e.g. "injected presets into 127 aircraft", "injected waypoints into 0 aircraft groups", "injected N aircraft groups", "created 6 weather variants"), so a `0` count immediately flags a configuration problem.
- `weather` pipeline step now uses `versions.yaml` exclusively — `missions.yaml` is no longer recognised as an alias; rename any existing `src/missions.yaml` to `src/versions.yaml`
- `mission.yaml` syntax simplified: `lua_modules:` + `community_scripts:` merged into a single `modules:` block; mandatory modules use bare null syntax (`MODULE:` with no value) instead of `MODULE: {}`; `enable:` replaced by `enabled:`; block-style lists replace inline `[...]`; generated files include a YAML syntax quick-reference header; legacy keys still accepted with a deprecation warning
- `convert-v5`: modules in generated `mission.yaml` are now sorted by category (Infrastructure → Core → Features → Combat → External); optional modules without extra config use `MODULE: true` shorthand instead of two-line block; community script IDs are emitted in uppercase (`MIST`, `STTS`, …); parser accepts uppercase or lowercase community IDs
- `mission.yaml` (all generators): each section now includes a `# Doc:` link to the relevant chapter of the Mission Maker Guide; section headers and descriptions improved (security, external modules, mandatory modules explanation)

### Fixed
- `convert-v5`: the generated `mission.yaml` now pre-resolves module dependencies — enabling a module such as `CASMISSION` automatically enables the modules it requires (`GROUNDAI`, `SPAWN`, and their transitive dependencies). The build no longer needs to auto-enable them with a warning, and the generated file accurately reflects what will run. The conversion report lists the auto-enabled modules.
- docs: removed the obsolete `convert` command from the Mission Maker Guide command tables (FR + EN); corrected the false "CSAR not available via mission.yaml" note in the mission.yaml reference (CSAR is supported via `external_modules.csar`); updated the Debug Logging section to reflect the single `veaf-scripts.lua` loader and `global_log_level`/`logLevel` control; created the missing French `veafInterpreter` page (fixes a broken FR nav link); consolidated duplicate `[Unreleased]` changelog sections and translated the stray French entry
- `veaf-tools-updater`: fixed the dead documentation URL shown on first install (`VEAF-Mission-Creation-Tools-v6/…` → `documentation/dev/…`)
- `convert-v5`: generated `mission.yaml` now includes the YAML syntax quick-reference header (was only present in `generate-config` output)
- `convert-v5`: all comment strings in generated `mission.yaml` are now localized via `t()` — French users see French comments
- `convert-v5`: multi-line Lua briefings using `..` concatenation (e.g. `"line1\n" .. "line2\n"`) are now fully extracted; `\n` escape sequences are decoded to real newlines and emitted as YAML block scalars
- `convert-v5`: `global_log_level` now defaults to `info` instead of `debug` when no log level is found in `missionConfig.lua`
- `convert-v5`: command now accepts being called without arguments (uses current directory by default); `no_args_is_help=True` removed
- `convert-v5`: all warning and manual-review messages are now fully translated via i18n — no more hardcoded English strings visible when running in French locale
- `veafRadio`: SRS config file absence no longer emits a warning — downgraded to `debug` when the file does not exist on disk
- `veafGrass`, `veafSpawnGround`, `veafSpawnEffects`: nil-safe guards added around `ctld.builtFOBS`, `ctld.logisticUnits`, `ctld.beaconCount` — prevent crashes when CTLD is not loaded or not yet initialized
- `presets inject`: `presets_assignments` keys now support regex patterns (e.g. `A[-]10C.*`, `FW[-]190.*`) — exact match takes priority, then pattern, then `all` fallback
- `convert-v5` presets: per-aircraft radio assignments are now extracted from `radioSettings` — warbird aircraft (e.g. Bf-109K-4) are auto-assigned to `{coalition}_warbird`, VHF-primary aircraft (e.g. I-16, Spitfire) get a new `{coalition}_vhf_primary` preset; hardcoded and typePattern entries emit explicit warnings listing the recommended preset
- i18n: all injector messages (presets, waypoints) and the radio frequency validator are now translated to French — no more English messages in the `veaf-tools build` log
- `presets inject`: radio frequency warnings are now deduplicated by aircraft type — instead of one warning block per group, a single block is emitted per unit type listing all affected groups in parentheses
- `build`: bundle `presets_injector/data/dcs-radio-specs.yaml` into the PyInstaller executable — fixes `ModuleNotFoundError: No module named 'presets_injector.data'` at runtime
- `aircraft-groups inject` (mode `add`): skip groups whose name already exists in the mission instead of creating duplicates — prevents DCS crash on FA-18C/F-16C units missing `datalinks` after a v5→v6 conversion
- `convert-v5`, `generate-config`, `migrate-config`: mandatory Lua modules (UNITS, TIME, CACHE, EVENTS, MARKERS, COMMANDS) are now emitted as `{}` in `mission.yaml` instead of `enable: true`, which would cause a build error
- `convert-v5`: `_BASE_ALWAYS_ON` now includes COMMANDS (previously missing) and is derived from the canonical `MANDATORY_MODULES` set
- `mission.yaml` (all generators and the default template): fixed broken doc URL (`doc/MISSION_MAKER_GUIDE.md` → `doc/mission-maker/GUIDE.en.md`)

---

## [6.3.4] — 2026-06-07

### Added
- `mission.yaml`: new `custom_scripts` section to declare custom Lua scripts in `src/scripts/` — declared scripts are included silently and can opt out of automatic DCS load-trigger generation with `generate_load_trigger: false` (global default or per-script override)

### Fixed
- `veafQraManager.md/en.md`, `veafSkynetIadsHelper.md/en.md`: références à `missionConfig.lua` remplacées par `mission-script.lua`
- `mission_builder_README.py`, `mission_extractor_README.py`: arborescences mises à jour (`missionConfig.lua` → `mission-script.lua`, ajout de `mission.yaml`)
- `veaf.lua`: commentaires AIEN/CTLD/CSAR mis à jour (`missionConfig.lua` → `mission-script.lua`, suppression de `(since v5.0)`)
- Fixtures de test (`veafDynamicConfig.lua`, `mapResource`): `missionConfig.lua` → `mission-script.lua`

### Removed
- `convert` command removed — it was broken on v6 missions (crash on missing `missionConfig.lua`) and its purpose is fully covered by `extract` followed by `build`

### Fixed
- `lua_config_generator.py`: specifying `enable` (true or false) on a mandatory Lua module in `mission.yaml` now raises an error instead of silently overriding — mandatory modules are always active and cannot be enabled or disabled


- `build.py`, `mission_builder_worker.py`: catch `yaml.YAMLError` when loading `mission.yaml` — display a clear, localised error message (file, line, column, plain-language hint) instead of crashing with a Python traceback

### Documentation
- `MISSION_YAML_REFERENCE.md`, `MISSION_YAML_REFERENCE.en.md`: added "Syntax errors" section explaining the new error messages and common causes

### Changed
- `mkdocs.yml`, `docs.yml`: deploy documentation to `veaf.github.io/documentation/` (was `veaf.github.io/VEAF-Mission-Creation-Tools-v6/`)
- Documentation: French is now the default language; English (`*.en.md`) is the secondary language — all 35 documentation page pairs renamed accordingly
- `mkdocs.yml`: `fr` locale set as default, `en` as secondary
- `doc/mission-maker/scripts/veafSkynetIadsHelper.md`: complete rewrite — corrected API names (`veafSkynet.*`), added point defence modes, group integration modes, dynamic spawn, command centers, network deactivation, and deferred network access pattern
- `doc/mission-maker/scripts/veafQraManager.md`: added note on `veafQraManager.initialize()` requirement for dynamic slots
- `doc/mission-maker/scripts/veafCombatZone.md`: added radio menu security note, cleanup options, and display options
- `doc/mission-maker/scripts/veafRadio.md`: added practical callback examples (QRA start/stop, group destroy, DCS flag management)
- `doc/mission-maker/scripts/veafWeather.md`: added fog management section (static/animated/dynamic constants, trigger usage, chat commands)

---

## [6.3.3] — 2026-06-06

### Fixed
- `veafCacheManager.lua`, `veafTime.lua`, `veafUnits.lua`, `veafSkynetIadsMonitor.lua`: added missing `initialize()` function — the generated `veaf-config.lua` calls `<module>.initialize()` on every listed module; absence caused a DCS runtime crash (`attempt to call field 'initialize' (a nil value)`)

### Added
- `mission_builder_worker.py`: `complete_src_folder_with_defaults()` now warns when unexpected `.lua` files are found in `src/scripts/` (potential v5 residues that would be loaded as DCS mission scripts and may conflict with the bundled `veaf-scripts.lua`)
- `prepare.py`: `.gitignore` template added to `src/defaults/mission-folder/` — copied on `veaf-tools prepare` when absent; never overwritten (even with `--force`) to preserve user customizations
- `lua_config_generator.py`: `_MODULE_CATEGORIES` dict — groups modules into 4 tiers (Infrastructure, Core, Features, Combat) plus External; category comment headers (`-- ── Category ──`) are emitted in `veaf-config.lua` and (`# ── Category ──`) in the YAML template
- `lua_config_generator.py`: `_MANDATORY_MODULES` frozenset — if a mandatory module (UNITS, TIME, CACHE, EVENTS, MARKERS, COMMANDS) has `enable: false`, a warning is logged and the flag is ignored (module still generated)
- `lua_config_generator.py`: `_MODULE_DEPS` dict + `_resolve_deps()` — after building the effective module list, missing or disabled dependencies are auto-enabled in memory with a `logger.warning` per auto-added module; transitive chains are fully resolved; disk is never modified
- `src/defaults/mission-folder/mission.yaml`: `lua_modules:` comment block reordered to match category grouping; Infrastructure modules annotated as mandatory
- `veaf_libs/build_profiles.py`: new `resolve_profile(yaml_data, profile_name)` function — deep-merges a named profile from the `profiles:` section of `mission.yaml` onto the base config; lists are replaced, not concatenated; `profiles:` key is stripped from the effective config
- `mission_builder_worker.py`: `MissionBuilderWorker.__init__` now accepts `profile_name: str | None`; calls `resolve_profile` immediately after loading `mission.yaml`, before any other config resolution
- `veaf_tools/commands/build.py`: new `--profile` / `-p` option on `veaf-tools build` to select a named build profile at build time
- `src/defaults/mission-folder/mission.yaml`: new commented `profiles:` section with `TEST` and `SERVER` examples
- `doc/MISSION_YAML_REFERENCE.md` (+ `.fr.md`): new `profiles:` section; entry added to the Build Pipeline index
- `doc/mission-maker/GUIDE.md` (+ `.fr.md`): new "Build Profiles" section explaining `--profile` usage with an example
- `lua_config_generator.py`: CSAR YAML support — `external_modules.csar` in `mission.yaml` generates `csar.xxx` property assignments and `csar.initialize()` in `veaf-config.lua`, symmetric to the existing CTLD support
- `lua_config_generator.py`: CTLD block now wrapped in `if ctld then … end` guard and includes `ctld.initialize()` call — no more manual `ctld.initialize()` required in `mission-script.lua` when using YAML-first config
- `doc/mission-maker/GUIDE.md` (+ `.fr.md`): CSAR YAML-first configuration documented; Lua fallback sections kept for complex settings (e.g. `aircraftType` tables)
- `doc/developer/GUIDE.md` (+ `.fr.md`): new "Developer Mode" section documenting `dev_mode` / `scripts_path` — concept, activation priority chain, workflow
- `doc/MISSION_YAML_REFERENCE.md` (+ `.fr.md`): new `build:` section documenting `dev_mode` and `scripts_path` fields

### Fixed
- `lua_config_generator.py`: asset `description`, `name`, `information` fields containing `\n` or `"` now use Lua long-string syntax (`[[...]]`) instead of plain `"..."` — prevents Lua syntax error at mission load
- `mission_builder_worker.py`: `complete_src_folder_with_defaults()` no longer copies the default `versions.yaml` when a legacy `missions.yaml` already exists in `src/`; emits a warning prompting to rename it
- `mission_builder_worker.py`: added `missions.yaml` to `_DEFAULT_FILE_MODULE_MAP` (pipeline `weather`) — covers future orphan-warning cases
- `v5_converter.py`: migration backup now uses the original filename `missionConfig.lua` instead of `missionConfig.lua.bak` — consistent with all other backup files in `backup_v5/`
- `mission_builder_worker.py`: `_DEFAULT_FILE_MODULE_MAP` no longer includes `presets.md`; corresponding default file `src/defaults/mission-folder/src/presets.md` deleted — docs are online, silent file creation was undesirable
- `build.py`: warn when `src/aircraft-templates.yaml` exists in the mission folder but the `aircraft_groups` pipeline step is disabled or skipped

---

## [6.3.2] — 2026-06-05

### Added
- `pyproject.toml` + `veaf_tools/app.py`: point d'entrée Poetry `veaf-tools` (équivalent à l'exe) avec affichage de la version au démarrage
- `veaf-tools.py`, `veaf-tools-updater.py`: pause automatique en fin d'exécution quand lancé par double-clic (détection par remontée de l'arbre de processus Windows, compatible PyInstaller one-file)

### Fixed
- `aircrafts_injector_worker.py`: lookup de country case-insensitive + préservation du champ `id` DCS lors de la création d'une country → empêche le crash `attempt to index field '?' (a nil value)` dans `me_mission.lua:fixCountriesNames` au chargement de mission

---

## [6.3.0] — 2026-05-31

### Added
- `veaf.initialize()`: nil-check for `veafCommands` with a clear error message if using outdated `veaf-scripts.lua` (IMC-010)
- `doc/MISSION_YAML_REFERENCE.md`: new intro section distinguishing build-pipeline YAML files from runtime `mission.yaml` config, with an ASCII tree diagram (IMC-007)
- Tests for `_is_double_clicked()` (IMC-001), annotated content in `ConversionReport.to_markdown()` (IMC-002), `complete_src_folder_with_defaults()` filtering and orphan warning (IMC-008), and `luadata._sort()` mixed-key crash (SORT-001)

### Fixed
- `luadata.serializer.serialize._sort()`: crash `TypeError: '<' not supported between instances of 'int' and 'str'` when sorting a Lua table with mixed integer and string keys (regression seen during v5 → v6 mission conversion) (SORT-001)

### Changed
- `veaf-tools convert-v5`: annotated `missionConfig.lua` is now embedded as a code block in `convert-v5-report.md` instead of being written to `backup_v5/src/scripts/missionConfig.lua`; a `README.txt` is added to `backup_v5/` explaining its contents (IMC-002)
- `veaf-tools build`: auto-pauses before exit when launched by double-click (Explorer.exe parent process) without an explicit `--pause`/`--no-pause` flag — no pause in CI or piped output (IMC-001)
- `complete_src_folder_with_defaults()`: skips copying a default file when its associated pipeline step or Lua module is disabled in `mission.yaml`; emits a warning if the now-orphan file already exists in the mission folder (IMC-008)

### Removed
- `src/defaults/mission-folder/src/README-versions.md` — stray documentation file removed from the defaults folder (IMC-003)

---

## [6.2.0] — 2026-05-30

### Added
- `veafCommands.lua` — central priority-ordered command dispatcher for F10 markers and interpreter path; exposes `registerCommandHandler(fn, priority)` and priority constants (`PRIORITY_SHORTCUTS`…`PRIORITY_REMOTE`)
- `veafSpawnParser.lua` — spawn command text parser extracted from `veafSpawnCore.lua` (`convertLaserToFreq`, `markTextAnalysis`)
- `veafRemote.registerRemoteModule(name, fn)` — registry for hook-server remote commands (replaces hardcoded if/elseif in `executeCommandFromRemote`)
- `backlog.md` — operational backlog with ticket estimates
- `doc/ROADMAP.md` — project roadmap
- `CHANGELOG.md` — this file
- `veaf.lp()` — lazy log argument proxy: arguments are only stringified when the active log level warrants it
- `mission.yaml: global_log_level` — replaces `--scripts-variant`; writes `veaf.ForcedLogLevel` in the generated `veaf-modules-config.lua`
- `--log-modules` option on `veaf-tools build` to selectively set log levels per module
- `.github/workflows/release.yml` — automated release on `published-v*` tag push (build + publish via GitHub Actions, zero manual intervention)
- `--ci` flag on `veaf-build publish` and `veaf-build build-and-publish` for non-interactive CI mode
- `veaf_tools/_version.py` committed stub — version injected by `worker.py` at PyInstaller build time, restored to `"unknown"` after; `app.py` and `veaf-tools-updater.py` resolve `VERSION` via `importlib.metadata` then `_version.__version__` fallback (VER-001)
- `about` command now prints `veaf-tools vX.Y.Z` before VEAF info (VER-003)
- Windows PE version metadata (FILE_VERSION / PRODUCT_VERSION) embedded in `veaf-tools.exe` and `veaf-tools-updater.exe` via `VSVersionInfo` generated dynamically at build time (VER-002)
- `ConfigMigrator` test coverage: integration tests on real fixtures (`mission-builder` and `demo-mission`) + unit tests for all 9 extractors previously untested (MIG-001, MIG-002)
- `doc/PIPELINE_REFERENCE.md` (+ `.fr.md`) — full YAML reference for all 4 pipeline steps (presets, waypoints, aircraft groups, weather/time) (DOC-001)
- `doc/MISSION_YAML_REFERENCE.md` (+ `.fr.md`) — hub page for `mission.yaml` top-level sections; category index and module index (DOC-002)
- `## Configuration (mission.yaml)` sections added to: `veafRadio`, `veafShortcuts`, `veafNamedPoints`, `veafCarrierOperations`, `veafAssets`, `veafSanctuary`, `veafCombatZone`, `veafAirWaves`, `veafQraManager`, `veafCasMission` (DOC-003 to DOC-006)
- `doc/mission-maker/scripts/veafRadio.fr.md` — created (was missing) (DOC-003)
- Module index in `MISSION_YAML_REFERENCE.md` completed with direct anchored links to every module's YAML section (DOC-007)
- `doc/index.md` (+ `.fr.md`) — hook sentence added before role table; `flowchart LR` → `flowchart TD` (REV-007)
- `doc/mission-maker/GUIDE.md` (+ `.fr.md`) — DCS Mission Editor added to prerequisites; base mission requirement (blue + red ground group) documented; Notepad++ listed as recommended editor (REV-008)
- `doc/mission-maker/GUIDE.md` (+ `.fr.md`) — CTLD/CSAR section: YAML-first approach via `external_modules.ctld` documented; CSAR YAML config noted as planned; `Intégration CTLD et CSAR` section added to French guide (was missing) (REV-010)
- `doc/mission-maker/MIGRATION_GUIDE.md` (+ `.fr.md`) — "Common Issues": refs to `missionConfig.lua` replaced by `mission.yaml` YAML config; "Reading the logs" entry added (Klogg + Notepad++) (REV-004)

### Changed
- `veaf_build/lua_tests.py`: `Optional[str]` migrated to `str | None` (UP007 now enforced)
- `pyproject.toml`: `UP007` removed from ruff ignore list — `str | None` union syntax enforced across all Python files
- `pyproject.toml`: `testpaths` changed to `["test/python"]` — test discovery now targets the new location
- 28 `test_*.py` files moved from `src/python/veaf-tools/**` to `test/python/**` — mirrors `test/lua/` convention (TST-001)
- `veaf_libs/paths.py`: `resolve_mission_file` glob branch now returns `.resolve()` path — fixes Windows short-path comparison
- `src/defaults/mission-folder/mission.yaml`: `versions.yaml` is now the canonical filename for the weather pipeline step; `missions.yaml` noted as legacy alias (REV-001)
- `src/python/veaf-tools/veaf_libs/lua_config_generator.py`: generated `mission.yaml` template comment updated to `versions.yaml` (REV-001)
- `doc/mission-maker/GUIDE.md` (+ `.fr.md`) — "Typical Build Workflow" simplified to `veaf-tools.exe build`; individual inject-* commands moved to collapsible Advanced section (REV-006)

### Changed (Shortcuts, Spawn, NamedPoints, CasMission, Security, Move, Radio, Remote) self-register via `veafCommands.registerCommandHandler()` — per-module `onEventMarkChange` functions removed
- Developer Guide (`doc/developer/GUIDE.md` + `.fr.md`) — Mermaid architecture diagram and runtime logging section updated to reference `veaf-config.lua` and `mission-script.lua` (v6) instead of the v5 `missionconfig.lua` (DOC-008)
- `veafInterpreter.execute()` delegates to `veafCommands.execute()` — hardcoded 8-branch if/elseif removed
- `mission_tools.DcsMission` — added `Group` dataclass and `iter_groups()` iterator; all injectors now share a single traversal path (DEEP-001)
- `mission_tools.DcsMission` — added `get_weather()` / `set_weather()` / `get_options()` / `set_options()` accessors; `WeatherInjectorWorker` updated to use them (DEEP-002)
- `WaypointsInjectorWorker`, `PresetsInjectorWorker` — local group traversal removed; now delegated to `DcsMission.iter_groups()` (DEEP-003)
- `veafCommands.lua` — added `PRIORITY_GROUNDAI = 62` constant (DEEP-005)
- `veafGroundAI.initialize()` — migrated from `veafMarkers.registerEventHandler` to `veafCommands.registerCommandHandler` at `PRIORITY_GROUNDAI` (DEEP-005)
- `veafSpawnParser.markTextAnalysis()` — common option defaults now in a single header block; type-specific defaults moved into their respective IF/ELSEIF branches (DEEP-006)
- `MissionBuilderWorker.__init__()` — now reads `mission.yaml`, resolves `dev_mode` / `scripts_path` from priority chain (CLI override > YAML > user config), and applies `log_modules_filter`; `build.py` simplified from ~180 to ~110 lines (DEEP-007)

### Added
- `veaf_libs.GroupInjectorWorker` — abstract base class for group-iterating injectors; `PresetsInjectorWorker` and `WaypointsInjectorWorker` now inherit from it (DEEP-004)
- `veafSpawnCore.lua` reduced from ~1834 to ~900 lines: parser extracted; 25-branch if/elseif replaced by handler dispatch loop
- `veafSpawnGround`, `veafSpawnAircraft`, `veafSpawnEffects` sub-modules self-register their spawn handlers via `veafSpawn.registerCommandHandler()`
- 7 remote modules self-register via `veafRemote.registerRemoteModule()` — hardcoded switch in `executeCommandFromRemote` removed
- Branch renamed from `develop/v6-new-build-system` to `develop-v6`
- `veaf.BaseLogLevel` default changed from `trace` to `info`
- All 1233 `veaf.p(` log-argument calls migrated to `veaf.lp(` across all Lua scripts
- Single build output (`veaf-scripts.lua`) — `veaf-scripts-debug.lua` / `veaf-scripts-trace.lua` variants removed
- `build-and-release.py`: removed build-time comment-out step and `_create_lua_variant_files()`
- `cliff.toml`: `tag_pattern` now matches both `published-v*` and `v*` tags

### Removed
- `module.onEventMarkChange()` functions from all 8 command modules (routing now handled by `veafCommands`)
- Hardcoded 8-branch command dispatch in `veafInterpreter.execute()`
- Hardcoded 25-branch if/elseif in `veafSpawnCore.executeCommand()`
- Hardcoded module switch in `veafRemote.executeCommandFromRemote()`
- `--scripts-variant` option from `veaf-tools build` and `veaf-tools convert`
- `.github/workflows/changelog.yml` — superseded by `release.yml`

---

## [6.0.5] — 2025-12-10

### Added
- Waypoint extractor and injector commands (`extract-waypoints`, `inject-waypoints`)
- Lua script debug and trace variants for enhanced mission development
- Option to hide radio menus for mission creators
- Defaults included in published artifacts for better out-of-the-box experience
- Confirmation prompt before overwriting `RELEASE_NOTES.md` during build

### Changed
- IADS package is now optional — missions that don't require IADS can omit it
- Refactored script file handling using `DEFAULT_SCRIPTS_LOCATION` constant for improved consistency
- Improved logging levels in Lua scripts for better clarity during development
- Streamlined mission conversion with better path management and error signaling
- Improved error signaling for missing VEAF and community script files

### Fixed
- File locking issues during updater operations
- Script path handling in mission builder
- CI: StyLua CRLF → LF line ending fix for cross-platform CI

---

## [6.0.2] — 2025-11-12

### Added
- Centralized `veaf_libs` module for logging and progress management (shared across all tools)

### Changed
- Migrated logging and progress management from individual tools to `veaf_libs`
- Updated version to 6.0.2

### Fixed
- Bug corrections in presets injector

---

## [6.0.1] — 2025-10-27

### Added
- `--pause` option on all commands — keeps the terminal open after execution for review

---

## [6.0.0] — 2025-10-26

### Added
- New `veaf-tools` CLI with 11 commands: `build`, `extract`, `convert`, `inject-presets`, `extract-aircraft-groups`, `inject-aircraft-groups`, `extract-waypoints`, `inject-waypoints`, `inject-weather`, `about`
- Auto-update mechanism via `veaf-tools-updater.exe`
- Radio presets injector with kneeboard image generation (PNG)
- Aircraft groups extractor and injector
- Weather injector (YAML-driven)
- Scripts injector — injects VEAF Lua scripts into missions
- Mission normalizer — deterministic Lua serialization to minimize diff noise
- Mission converter — converts legacy missions to v6 format
- Persian Gulf airport frequencies
- Documentation restructured into `doc/` folder by audience (pilot, mission maker, developer)
- GitHub Actions CI: `lua-unit-tests` + `stylua-check` jobs
- 31 Lua test suites (~915 tests) with `luaunit`, `dcs_mocks.lua`, `run_tests.ps1`

### Changed
- Reworked publication mechanism — `build-and-release.py` now orchestrates the full pipeline
- Refactored build and release: removed `published/` directory handling in favor of local ZIP artifacts
- Enhanced logging and error reporting throughout

### Fixed
- Trigger insertion method rewrite for reliability
- Normalizer sort key stability
- Presets injector: no duplicate kneeboard image files, inject only into human units

---

## v5.x

See git tags (`v5.80.0` → `v5.103.3`) for full v5 history.
Last v5 release: **v5.103.3**.
