# Lot TODO0609-ERA-AUTODETECT — Automatic mission era detection

Status: ✅ done

**Goal**: The mission era (especially `WW2`) is currently manual or extracted from v5 only if present. Add automatic detection from the `.miz` content when `era` is not provided. A manual `mission.yaml` `era` always wins. Covers todo-2026.06.09 item 7.

**Decision** (grilling 2026-06-10): combined heuristic — mission year **and** WW2-era unit/aircraft types — with a `mission.yaml` override that always takes precedence.

**Branch**: `feat/era-autodetect` → PR → `develop`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| ERA-AUTODETECT-001 | Detection helper combining the DCS mission year and a WW2 unit/aircraft-type reference list to infer the era; document the priority rule. Unit tests over fixtures (WW2 by year, WW2 by units, modern, ambiguous). | `mission_builder/`, `test/python/` | feat | ✅ |
| ERA-AUTODETECT-002 | Wire the helper into conversion/build: use detected era only when `mission.yaml` `era` is absent; manual value always wins. Maintain the WW2-era types reference table. | `mission_builder/config_migrator.py` / `mission_builder/mission_builder_worker.py`, `test/python/` | feat | ✅ |
