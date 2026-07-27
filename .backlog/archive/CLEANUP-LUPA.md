# Lot CLEANUP-LUPA — remove the dead `lupa` dependency

Status: ✅ done

**Goal**: SECREV-001 routed all `.miz`/Lua parsing through the pure-Python `luadata` state machine to remove the RCE, but `lupa` was still bundled — a non-optional dependency + `hiddenimports` in the `.spec` (RC-002) — and still referenced in two dead spots: the unused `_lua_table_to_dict` path in the vendored `luadata` serializer, and the lupa-based reference oracle in `test_secrev_rce.py`. It is dead weight in the dependency tree and the binary. Remove it. (Surfaced while planning FOOTHOLD-V6: the config-validation design deliberately avoids reintroducing lupa.)

**Branch**: `chore/cleanup-lupa` → PR → `develop`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| CLEANUP-LUPA-001 | Drop `lupa` from `pyproject.toml` dependencies + the `lupa.*` mypy override, from the `hiddenimports` in `veaf-tools.spec`; remove the dead lupa import + `_lua_table_to_dict` from the vendored `luadata` serializer and the lupa reference oracle from `test_secrev_rce.py` (re-pin the dict/list policy with direct expected-value assertions + a real-`.miz` parse smoke test). No `import lupa` remains. | `pyproject.toml`, `veaf-tools.spec`, `luadata/serializer/unserialize.py`, `test/python/` | chore | ✅ |
