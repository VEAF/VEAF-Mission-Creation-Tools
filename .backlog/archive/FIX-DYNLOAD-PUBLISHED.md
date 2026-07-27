# Lot FIX-DYNLOAD-PUBLISHED — make dynamic loading work in DEV and PROD

Status: ✅ done

**Goal**: Dynamic loading was broken from a `published/` install (Flogas): the build always emitted the DEV framework loader (`VeafDynamicLoader.lua`, which `loadfile`s the **individual** `veaf/*.lua`), but `published.zip` ships only the concatenated **bundle** `veaf/veaf-scripts.lua` — so the individual files were absent → runtime "no file" error. Also, the mission maker's `custom_scripts` were never loaded dynamically (the hand-maintained `veafDynamicConfig.lua` only listed `mission-script.lua`). Per David: support two scenarios — **DEV** (load individual scripts from a repo checkout, `scripts_path`) and **PROD** (load the bundle from `scripts_path`, default `./published`) — and in both, load the mission maker's custom scripts dynamically.

**Branch**: `feat/dynload-prod` → PR → `develop`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| DYNLOAD-PROD-001 | Framework loader depends on mode: DEV (`dev_mode: true`) → `VeafDynamicLoader.lua` (individual scripts from the repo); PROD → bundle `veaf/veaf-scripts.lua` from `scripts_path` (default `published/`, already in `published.zip` — no packaging change). Applied to both the trigger and trigrule forms. | `mission_builder/mission_builder_worker.py`, `test/python/` | feat | ✅ |
| DYNLOAD-PROD-002 | Generate `src/scripts/veafDynamicConfig.lua` from the mission script list (`mission-script.lua` + `custom_scripts`, same order as the static triggers) so dynamic mode loads the mission maker's custom scripts too. File becomes generated (documented "do not edit"). | `mission_builder/mission_builder_worker.py`, `src/defaults/mission-folder/src/scripts/veafDynamicConfig.lua`, locales, `test/python/` | feat | ✅ |
| DYNLOAD-PROD-003 | Build-time validation: if dynamic loading is on and the framework loader is missing under `scripts_path` (DEV: `VeafDynamicLoader.lua`; PROD: `veaf/veaf-scripts.lua`), fail with a clear localized error instead of shipping a `.miz` that breaks at runtime. Document DEV/PROD in `MISSION_YAML_REFERENCE*`. | `mission_builder/mission_builder_worker.py`, locales, `doc/`, `test/python/` | feat | ✅ |
