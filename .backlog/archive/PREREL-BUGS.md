# Lot PREREL-BUGS — Pre-release code review findings

Status: ✅ done

**Goal**: Fix bugs found during a verified pre-release code review (unrelated to the documentation lot). These block the next `develop` release. B1 is a functional regression and should be fixed first.

**Branch**: `fix/prerel-bugs` → PR → `develop` (Python changes; separate from the doc PR)

| # | Ticket | Type | Status |
|---|--------|------|--------|
| PREREL-001 (B1) | **Regression** — `config_migrator.py` `_lua_extract_string()` over-collects quoted strings after `:setBriefing(`: a briefing absorbs following setter strings in the same call chain. Introduced by the multiline fix (PR #390), reproduced empirically. Fix: bound the search to the matching `)` of `:setBriefing(`. Add a regression test covering a chained `:setBriefing("..."):setX("...")` case. | fix | ✅ |
| PREREL-002 (B2) | `mission_builder_worker.py` (~L339): `exit()` returns code 0 after a fatal error, so a failed build is reported as success. Use a non-zero exit code / raise. | fix | ✅ |
| PREREL-003 (B3/B4) | Hardcoded English in `mission_builder_worker.py`: ~L333-338 missing-files message and ~L1168 `"Injecting dcs-bridge.lua"` spinner must use `t()`; add FR translations to `fr.json`. | fix | ✅ |
| PREREL-004 (I1) | `paths.py`: replace `exit(-1)` with a raised exception (utility code should not call `exit()`; makes it testable). | fix | ✅ |
| PREREL-005 (cosmetic) | `v5_converter.py` (~L885): remove the dead `is None` branch (never reached). Low priority. | chore | ✅ |
