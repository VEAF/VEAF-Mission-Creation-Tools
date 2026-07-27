# Lot SECREV — Full-repo code review findings

Status: ✅ done

**Goal**: Fix the security and correctness defects surfaced by the full-repository code review. Two are release-blocking: arbitrary code execution when parsing any `.miz` file, and silent data loss when extracting helicopter groups.

**Branch**: `fix/secrev-findings` → PR → `develop`

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
