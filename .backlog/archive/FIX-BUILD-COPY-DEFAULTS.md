# Lot FIX-BUILD-COPY-DEFAULTS — copy default mission.yaml before reading config

Status: ✅ done

**Goal**: When the user has no `mission.yaml`, `build` resolved the config from the absent file in `MissionBuilderWorker.__init__` **before** `complete_src_folder_with_defaults()` (run later in `work()`) copied the default into the folder. Result: `self.mission_yaml` (and everything derived — `veaf-config.lua`, community toggles, custom_scripts, dynamic_mode) stayed empty → **no veaf-config.lua, no VEAF menu**, and all community scripts wrongly enabled. Fix the ordering so the default is available before the config is read.

**Branch**: `fix/build-copy-defaults-before-read` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| FIX-BUILD-COPY-DEFAULTS-001 | Add `_ensure_default_mission_yaml()` called at the very start of `__init__` (before the mission.yaml read): copy the default mission.yaml from `<scripts_path or mission/published/src>/defaults/mission-folder/` into the mission folder if missing. The later `complete_src_folder_with_defaults()` still copies the other defaults. Tests: absent mission.yaml → copied + config resolved (veaf-config, MiST kept, SKYNET off); existing mission.yaml not overwritten. | `mission_builder/mission_builder_worker.py`, `test/python/` | fix | ✅ |
