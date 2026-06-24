# Lot FIX-CONVERT-V5-LOG-DEFAULT — convert-v5 defaults global_log_level to debug instead of info

Status: ✅ done

**Goal**: Change the fallback value for `global_log_level` in the generated `mission.yaml` from `debug` to `info`, so missions converted with no prior log level set are not silently deployed in debug mode.

**Root cause**: `v5_converter.py:811` — `f"global_log_level: {extracted_ll or 'debug'}"`. When `missionConfig.lua` had no explicit log level, `extracted_ll` is `None` and the fallback is `'debug'`. The inline comment even warns *"Remove or set to 'info' before deploying to players"* — but the default does the opposite.

**Fix**: Change `'debug'` → `'info'` in the fallback.

**Branch**: `fix/convert-v5-log-default` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| CVLOG-001 | Change fallback `'debug'` → `'info'` in `_build_mission_yaml_lines` | `src/python/veaf-tools/mission_builder/v5_converter.py` | fix | 5 min | ✅ |
