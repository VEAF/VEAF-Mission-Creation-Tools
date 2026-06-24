# Lot FIX-BRIEFING-MULTILINE — convert-v5 truncates multi-line Lua briefings

Status: ✅ done

**Goal**: `setBriefing("line1\n" .. "line2\n")` must produce a complete multiline string in `mission.yaml`; currently only the first fragment is captured and literal `\n` is not decoded to a real newline.

**Root causes**:
1. `config_migrator.py` regex `"([^"]*)"` stops at first `"..."` fragment — ignores Lua `..` concatenation.
2. Lua escape `\n` is kept as literal `\n` instead of being decoded to a real newline.
3. `_yaml_str()` in `v5_converter.py` does not handle strings containing real newlines.
4. CAP mission briefings emitted inline via `_yaml_str()` instead of block scalar.

**Branch**: `fix/briefing-multiline` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| BML-001 | Add `_lua_extract_string()` helper + apply to 3 `setBriefing` extraction sites | `config_migrator.py` | fix | 15 min | ✅ |
| BML-002 | `_yaml_str()`: handle strings with real newlines; CAP mission briefing → block scalar | `v5_converter.py` | fix | 10 min | ✅ |
| BML-003 | Tests | `test_config_migrator.py` | test | 20 min | ✅ |
