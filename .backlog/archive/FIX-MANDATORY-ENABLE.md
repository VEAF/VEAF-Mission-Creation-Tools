# Lot FIX-MANDATORY-ENABLE — block enable on mandatory modules

Status: ✅ done

**Goal**: Prevent users from explicitly setting `enable: true` (or any value) on mandatory modules in `mission.yaml`; emit a clear error at build time.

**Branch**: `fix/mandatory-yaml-enable` → PR → `develop-v6`

| # | Ticket | Type | Effort | Status |
|---|--------|------|--------|--------|
| FME-001 | Detect mandatory-module `enable:` keys in `mission_builder_worker.py` and raise a critical error | fix | 10 min | ✅ |
| FME-002 | Test: verify error is raised when mandatory module has `enable: true` | test | 10 min | ✅ |
