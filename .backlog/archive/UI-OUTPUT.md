# Lot UI-OUTPUT — Declutter CLI output (transient status line + chapter/technical tiers)

Status: ✅ done

**Goal**: Make `veaf-tools` (and later `veaf-tools-updater`) output readable. Low-importance progress messages scroll endlessly today. Introduce three output tiers: permanent technical lines, permanent chapter headers, and a single overwriting transient line for everything else (warnings/errors stay permanent). The full log file keeps every message. `--verbose` and non-interactive output fall back to the classic line-by-line display.

**Branch**: `feature/UI-OUTPUT` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| UIOUT-001 | `StatusLine` helper: single overwriting Rich `Live` line, enable/disable, suspend for nested `Live` | `veaf_libs/console_status.py` | feat | ✅ |
| UIOUT-002 | Wire into `Logger`: `info()` transient by default, add `tech()`/`step()`, `set_verbose` gates transient on TTY, `stop_status()` | `veaf_libs/logger.py` | feat | ✅ |
| UIOUT-003 | Make `spinner_context`/`progress_context` suspend the status line and render transiently when active | `veaf_libs/progress.py` | feat | ✅ |
| UIOUT-004 | Pilot `build`: promote pipeline headers to `step()`, key results to `tech()`; stop status line at program end | `veaf_tools/commands/build.py`, `veaf_tools/app.py`, `mission_builder/mission_builder_worker.py` | feat | ✅ |
| UIOUT-005 | Unit tests for `StatusLine` and `Logger` routing | `test/python/veaf_libs/test_console_status.py`, `test_logger.py` | test | ✅ |
| UIOUT-006 | Phase 2 — extend to `veaf-tools-updater` and `veaf-build`: `stop_status()` at program exit + promote outcome lines to `tech()` | `veaf-tools-updater.py`, `veaf_build/cli.py` | feat | ✅ |
