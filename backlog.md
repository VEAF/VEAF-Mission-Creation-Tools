# Backlog — VEAF Mission Creation Tools v6

## Legend

- **Type**: `feat` / `fix` / `chore`
- **Status**: `⬜` to do · `🔄` in progress · `✅` done

> Completed lots are moved to [backlog-archive.md](backlog-archive.md).

---

## Summary

| Lot | Status |
|-----|--------|
| Phase 0b — GitHub cleanup | ⬜ |
| Lot 5 — RELEASE | ⬜ |
| Lot FIX-I18N-CONVERT-V5 — Hardcoded English messages in convert-v5 | ✅ |
| Lot PREREL-BUGS — pre-release code review findings (briefing over-capture, exit codes, i18n, error handling) | ⬜ |
| Lot SECREV — full-repo code review findings (lupa RCE, helicopter extraction data loss, zip hardening, Lua nil-derefs) | ⬜ |

---

## Lot SECREV — Full-repo code review findings

**Goal**: Fix the security and correctness defects surfaced by the full-repository code review. Two are release-blocking: arbitrary code execution when parsing any `.miz` file, and silent data loss when extracting helicopter groups.

**Branch**: `fix/secrev-findings` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| SECREV-001 | **RCE**: `luadata.unserialize()` runs `lua.execute(raw)` on untrusted `.miz` content via an unsandboxed lupa runtime. Route `.miz` parsing through the existing pure-Python `_unserialize()` state machine (preferred), or harden the runtime (`register_eval=False`, strip `os`/`io`/`load`/`loadfile`/`dofile`/`package`/`require` from globals, bound `max_memory`). Add regression tests with a malicious `.miz` payload asserting no execution. | `luadata/serializer/unserialize.py`, `mission_tools/miz_tools.py`, `test/python/` | fix | ⬜ |
| SECREV-002 | **Data loss**: helicopter-matching block (lines 1075-1086) is dedented one level, so only the last helicopter group per country is extracted. Re-indent into the `for group` loop. Regression test: extract a mission with ≥2 helicopter groups in one country, assert all present. | `aircrafts_injector/aircrafts_injector_worker.py`, `test/python/` | fix | ⬜ |
| SECREV-003 | Replace `eval()` in the time-expression parser with a safe AST-based arithmetic evaluator (or numeric/operator allowlist); guard against DoS expressions. Tests for valid and rejected inputs. | `weather_injector/utils/time_expression_parser.py`, `test/python/` | fix | ⬜ |
| SECREV-004 | **Zip Slip**: validate every member name before `extractall` (reject absolute paths and entries escaping the destination) in `.miz` extraction and the updater. | `mission_tools/miz_tools.py`, `veaf-tools-updater.py`, `test/python/` | fix | ⬜ |
| SECREV-005 | **Zip-bomb**: cap total uncompressed size and entry count before extracting `.miz` and `published.zip`. | `mission_tools/miz_tools.py`, `veaf-tools-updater.py`, `test/python/` | fix | ⬜ |
| SECREV-006 | `convert_weather` truthiness guards (`if temp := ...`) silently drop legitimate `0` values (temperature, wind speed/direction, visibility). Use `is not None`. Tests for zero-valued weather params. | `mission_builder/v5_pipeline_converters.py`, `test/python/` | fix | ⬜ |
| SECREV-007 | Lua nil-deref crashes: `spawnConvoy` `size / 2` without nil-guard (`veafSpawnGround.lua:635`); `generateAirDefenseGroup` mutates nil group after error (`veafCasMission.lua:763`); `getAtcForCarrierOperations`/`stopCarrierOperations` deref carrier before nil-check (`veafCarrierOperations.lua:662,789`). Add guards + luaunit tests. | `src/scripts/veaf/veafSpawnGround.lua`, `veafCasMission.lua`, `veafCarrierOperations.lua`, `test/lua/` | fix | ⬜ |
| SECREV-008 | `veafAirWaves.addWave` string-list branch inserts the whole `parameter` table instead of element `s` (`veafAirWaves.lua:307`). Fix + test. | `src/scripts/veaf/veafAirWaves.lua`, `test/lua/` | fix | ⬜ |
| SECREV-009 | `veafSecurity`: stop logging the cleartext password at debug (`:552`); fix `isAuthenticated` reading the never-assigned `veafSecurity.SecurityDisabled` instead of `veaf.SecurityDisabled` (`:656`). | `src/scripts/veaf/veafSecurity.lua`, `test/lua/` | fix | ⬜ |
| SECREV-010 | `veafMove.markTextAnalysis` mandatory-group guard never fires (`groupName` defaults to `""`, truthy). Reject empty group name (`veafMove.lua:240`). Fix + test. | `src/scripts/veaf/veafMove.lua`, `test/lua/` | fix | ⬜ |

**Out of scope (need a design decision first, tracked separately)**: remote `login` trusting the server-supplied auth level without password validation (`veafSecurity.lua:427`), and potential shell injection via crafted SRS radio message text (`veafRadio.lua:759`). Both are gated behind L1/server trust; raise with the team before changing the auth model.

---

## Phase 0b — GitHub cleanup

Close issues identified during triage. **Verify each one before closing.**
Direct commits on `develop-v6` (no feature branch needed — no code change).

| # | Ticket | Type | Status |
|---|--------|------|--------|
| CLOSE-001 | Close WONTFIX issues: #55, #146, #147, #180, #193, #246 | chore | ⬜ |
| CLOSE-002 | Close STALE issues: #9, #19, #41, #167 | chore | ⬜ |

<details>
<summary>Issues to close</summary>

**WONTFIX — Already implemented or out of scope**

| # | Title | Reason |
|---|-------|--------|
| #55 | Faire un système de zone de combat dynamique | Already implemented → `veafCombatZone` |
| #146 | CTLD JTAC 9-line | External project (CTLD/Ciribob) |
| #147 | CTLD JTAC Ask for wind/speed correction | External project (CTLD/Ciribob) |
| #180 | AirWaves - forcer à rester dans la zone | Both tasks already checked ✅ in the issue |
| #193 | CTLD - gestion d'emport multiple de caisses | Requires upstream PR to CTLD, out of scope |
| #246 | CTLD - orientation des unités Patriot | CTLD external bug, out of scope |

**STALE — No activity, too vague, or superseded**

| # | Title | Reason |
|---|-------|--------|
| #9 | Marker command to build a transport mission interception | 2018, no activity since 2021, too vague |
| #19 | Idée - spawn facile avec inventaire des unités par coalition | 2020, informal idea, no spec |
| #41 | Tester spawn humains CASE 1 téléportés à la bonne position | 2021, vague, no activity |
| #167 | Tester gRPC | 2023 tech spike, no follow-up planned |

</details>

---

## Lot 5 — RELEASE: v6.1.0

**Goal**: Merge v6 to master and publish the official release.
**From**: `develop-v6` directly

| # | Ticket | Type | Depends on | Status |
|---|--------|------|------------|--------|
| REL-001 | Finalize `CHANGELOG.md` for v6.1.0 | chore | Lots 1–4 | ⬜ |
| REL-002 | Write `RELEASE_NOTES.md` for v6.1.0 | chore | REL-001 | ⬜ |
| REL-003 | Squash merge `develop-v6` → `master` | chore | REL-002 | ⬜ |
| REL-004 | Tag `v6.1.0` + publish GitHub (`veaf-build publish`) | chore | REL-003 | ⬜ |
| REL-005 | Change doc URL prefix from `/dev/` to `/latest/` in `v5_converter.py` (`DOC_BASE`, `_DOC_BASE`) and `src/defaults/mission-folder/mission.yaml` | chore | REL-003 | ⬜ |

---

## Lot PREREL-BUGS — Pre-release code review findings

**Goal**: Fix bugs found during a verified pre-release code review (unrelated to the documentation lot). These block the next `develop-v6` release. B1 is a functional regression and should be fixed first.

**Branch**: `fix/prerel-bugs` → PR → `develop-v6` (Python changes; separate from the doc PR)

| # | Ticket | Type | Status |
|---|--------|------|--------|
| PREREL-001 (B1) | **Regression** — `config_migrator.py` `_lua_extract_string()` over-collects quoted strings after `:setBriefing(`: a briefing absorbs following setter strings in the same call chain. Introduced by the multiline fix (PR #390), reproduced empirically. Fix: bound the search to the matching `)` of `:setBriefing(`. Add a regression test covering a chained `:setBriefing("..."):setX("...")` case. | fix | ⬜ |
| PREREL-002 (B2) | `mission_builder_worker.py` (~L339): `exit()` returns code 0 after a fatal error, so a failed build is reported as success. Use a non-zero exit code / raise. | fix | ⬜ |
| PREREL-003 (B3/B4) | Hardcoded English in `mission_builder_worker.py`: ~L333-338 missing-files message and ~L1168 `"Injecting dcs-bridge.lua"` spinner must use `t()`; add FR translations to `fr.json`. | fix | ⬜ |
| PREREL-004 (I1) | `paths.py`: replace `exit(-1)` with a raised exception (utility code should not call `exit()`; makes it testable). | fix | ⬜ |
| PREREL-005 (cosmetic) | `v5_converter.py` (~L885): remove the dead `is None` branch (never reached). Low priority. | chore | ⬜ |

---
