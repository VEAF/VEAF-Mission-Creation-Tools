# Lot FEAT-YAML-MODULE-UX — Module shorthand, uppercase community IDs, category sort

Status: ✅ done

**Goal**: Improve readability of the generated `mission.yaml` from `convert-v5`:
1. Simple enabled modules use `MODULE: true` shorthand instead of two-line `MODULE:\n  enabled: true`
2. Community script IDs displayed in uppercase (`MIST`, `STTS`…) like VEAF modules
3. Modules sorted by category (Infrastructure first, then Core / Features / Combat / External)

**Branch**: `feature/yaml-module-ux` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| MUX-001 | `yaml_module_entry()`: add `has_config` param — emit `MODULE: true` when no extra config | `lua_config_generator.py` | feat | 10 min | ✅ |
| MUX-002 | v5_converter: pass `has_config=True` for modules with extracted data; sort by category | `v5_converter.py` | feat | 25 min | ✅ |
| MUX-003 | Community script keys uppercase in generated YAML; case-insensitive matching in parser | `v5_converter.py`, `mission_builder_worker.py` | feat | 15 min | ✅ |
| MUX-004 | Update tests | `test_v5_converter.py`, `test_lua_config_generator.py` | test | 10 min | ✅ |
