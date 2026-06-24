# Lot FIX-CONVERT-V5-COMMENTS — convert-v5 must ignore Lua comments

Status: ✅ done

**Goal**: `convert-v5` analyses `missionConfig.lua` to detect active modules and extract ASSETS/QRA definitions, but it does **not** respect Lua comments. In the standard VEAF template, each module body is shipped inside a `--[[ … ]]` "uncomment to enable" block; convert-v5 (1) treats a module as active from the `if veafXxx then` guard even when its entire body is commented, and (2) regex-scans `name=…` definitions **inside** `--[[ ]]` blocks, emitting phantom ASSETS/QRA into `mission.yaml`. Found during DCS-UPDATE-VERIFY (R7-BUG) on the Training-Syrie mission: 14 commented-out assets + QRA were emitted as active, then flagged "absent from the mission" at build (the real groups have different names). High impact — most real v5 missions ship config commented. **Fix**: strip Lua line (`--`) and block (`--[[ ]]`) comments from `missionConfig.lua` before module-activation detection and asset/QRA extraction; a commented module body should not enable the module or contribute definitions. Regression test on a fixture with a fully-commented `veafAssets.Assets` block.

**Branch**: `fix/convert-v5-comments` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| CV5COM-001 | Strip Lua comments before convert-v5's module-activation + ASSETS/QRA extraction; commented bodies contribute nothing; regression tests | `mission_builder/config_migrator.py`, `test/python/mission_builder/test_convert_v5_commented_modules.py` | fix | ✅ |
