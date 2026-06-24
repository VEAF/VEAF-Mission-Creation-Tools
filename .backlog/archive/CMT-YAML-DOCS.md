# Lot CMT-YAML-DOCS — doc comments and links in generated `mission.yaml` files

Status: ✅ done

**Goal**: Generated `mission.yaml` files (by `generate-config`, `convert-v5` and `prepare`) must contain explanatory comments and a link to the relevant documentation chapter for each section. The current URLs pointed to a non-existent file.

**Branch**: `fix/mandatory-yaml-enable` (amended on current branch)

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| CMT-001 | Fix the doc URL and add per-section links in `en.json` | `veaf_libs/locales/en.json` | chore | 10 min | ✅ |
| CMT-002 | Same fixes in `fr.json` | `veaf_libs/locales/fr.json` | chore | 10 min | ✅ |
| CMT-003 | Fix the URL and add per-section links in `v5_converter.py` | `mission_builder/v5_converter.py` | chore | 10 min | ✅ |
| CMT-004 | Fix the URL in `src/defaults/mission-folder/mission.yaml` | `src/defaults/mission-folder/mission.yaml` | chore | 5 min | ✅ |
| CMT-005 | Tests: verify links are present in generated YAML files | `test/python/` | test | 10 min | ✅ |
