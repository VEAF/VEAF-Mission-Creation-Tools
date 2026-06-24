# Lot FIX-AIRCRAFT-DUPLICATE — Duplicate aircraft groups in "add" injection mode

Status: ✅ done

**Goal**: Fix a DCS crash (`attempt to index global 'teamMemberDatalinks' (a nil value)`) caused by duplicate aircraft groups created during `inject_groups(mode="add")`. In add mode, groups already present in the mission were appended again from YAML, creating copies without `datalinks` metadata. The fix skips groups whose name already exists.

**Branch**: `fix/aircraft-duplicate-inject` → PR #375 → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| ADUP-001 | In `inject_groups(mode="add")`: skip groups whose name already exists in the mission instead of appending | `aircrafts_injector/aircrafts_injector_worker.py` | fix | 10 min | ✅ |
| ADUP-002 | Regression tests: duplicate skipped, original data preserved, mix add/skip, replace mode unaffected | `test/python/aircrafts_injector/test_aircrafts_injector_worker.py` | test | 10 min | ✅ |

---

Lots completed 2026-06-07 → 2026-06-09 (archived 2026-06-09, on request — ahead of the usual 3-day rule).
