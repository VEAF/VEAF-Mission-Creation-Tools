# Lot FIX-REMOVE-CONVERT — remove the `convert` command

Status: ✅ done

**Goal**: Remove the `convert` command which is broken on v6 missions (crashes on missing `missionConfig.lua`) and whose role is covered by `extract` + `build`.

**Branch**: `fix/remove-convert-command` → PR #371 → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| RMC-001 | Delete `commands/convert.py` and the `mission_converter/` package | `src/python/veaf-tools/` | chore | 5 min | ✅ |
| RMC-002 | Remove TUI entry and `cmd.convert.*` locale keys | `tui.py`, `en.json`, `fr.json` | chore | 10 min | ✅ |
| RMC-003 | Remove the corresponding test assertion | `test/python/veaf_libs/test_tui.py` | test | 5 min | ✅ |
