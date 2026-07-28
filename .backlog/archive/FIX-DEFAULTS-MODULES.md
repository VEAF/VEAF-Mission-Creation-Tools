# Lot FIX-DEFAULTS-MODULES — MiST mandatory, drop WEATHERMARK from default

Status: ✅ done

**Goal**: David's review of the default `mission.yaml`: (1) MiST is a hard VEAF dependency → must always be injected (like the mandatory infrastructure modules); (2) WEATHERMARK no longer belongs in our scripts → remove it from the default (full removal tracked separately); (3) TUM has no initialization in the generated config (kept in the default; init tracked separately).

**Branch**: `fix/defaults-mist-weathermark-tum` → PR → `develop`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| FIX-DEFAULTS-MODULES-001 | MiST mandatory: always inject the `mist` community script regardless of the `modules:` entry (`MANDATORY_COMMUNITY_SCRIPTS`); a bare `MIST:` is the default form (silent), an explicit `MIST: false` is warned and ignored. Default lists `MIST:` in the mandatory infrastructure block. Remove `WEATHERMARK` from the default. Tests for MiST-kept-when-disabled. | `mission_builder/mission_builder_worker.py`, `src/defaults/mission-folder/mission.yaml`, locales, `test/python/` | fix | ✅ |
