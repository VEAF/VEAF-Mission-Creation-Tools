# Lot QUALITY-GATE — Erode mypy exclusions and ratchet the coverage gate

Status: ✅ done

**Goal**: Two quality guards are advertised but neutralized where it matters. `pyproject.toml:102-120` sets `ignore_errors = true` for **every large worker** (`aircrafts_injector_worker`, `mission_builder_worker`, `mission_converter_worker`, `presets_*`, `waypoints_*`, `weather_*`), so mypy only type-checks already-clean small files — exactly where the SECREV defects did *not* hide. Line coverage is **16%** with `--cov-fail-under=15`, so the gate protects nothing. Turn both into a debt eroded lot-by-lot rather than a single big-bang. Supersedes the archived single-shot attempt (`backlog-archive.md` "Retirer `ignore_errors`…").

**Branch**: `chore/quality-gate` → PR → `develop`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| QUALITY-001 | Remove `ignore_errors` for the simplest still-excluded workers (start with `presets_injector_worker`, `waypoints_injector_worker`), fix the surfaced type errors, leave the rest. | `pyproject.toml`, touched workers, `test/python/` | chore | ✅ |
| QUALITY-002 | Document the ratchet policy in `CLAUDE.md` §3: every lot that substantially touches an excluded worker drops its `ignore_errors` entry as part of its Definition of Done; every lot that adds tests bumps `--cov-fail-under` so the gate never sits more than ~2 pts below actual coverage. | `CLAUDE.md`, `pyproject.toml` | chore | ✅ |

> Cross-cutting reminder: the worker-reopening lots (MODULES-UNIFY, AIRCRAFT-INJECT, CONVERT-FIDELITY, SECREV) should each drop the touched worker's mypy exclusion as part of their own work, so this lot only mops up the remainder. **`CLAUDE.md` §3 (Quality Ratchet Policy) is the single source of truth** for this rule; the notes here and in `ROADMAP.md` §2 are summaries.
