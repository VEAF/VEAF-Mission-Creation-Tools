# Lot FIX-YAML-SYNTAX — unhandled YAML error in build and mission_builder_worker

Status: ✅ done

**Goal**: Catch YAML syntax errors in `mission.yaml` to display a clear message instead of a Python traceback.

**Context**: An unhandled `yaml.YAMLError` in `build.py` (name peek) and `mission_builder_worker.py` (full load) caused a crash with traceback. PyYAML's native error message (file, line, column, context) is now propagated via `logger.error`.

**Branch**: `fix/yaml-syntax-error` → PR → `develop`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| YAML-SYNTAX-001 | Handle `yaml.YAMLError` in `build.py` (peek mission name) | `src/python/veaf-tools/veaf_tools/commands/build.py` | fix | 5 min | ✅ |
| YAML-SYNTAX-002 | Handle `yaml.YAMLError` in `mission_builder_worker.py` (full load) | `src/python/veaf-tools/mission_builder/mission_builder_worker.py` | fix | 5 min | ✅ |
