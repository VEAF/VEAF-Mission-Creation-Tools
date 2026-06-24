# Lot VALIDATE — `veaf-tools validate` (pre-build linter)

Status: ✅ done

**Goal**: add a `veaf-tools validate` command that lints a mission folder **before** build, turning late DCS-side crashes into clear design-time errors. Checks to cover: incoherent/unknown `modules:` entries, `custom_scripts` files that do not exist, presets/waypoints that match no aircraft in the `.miz`, missing REDFOR/BLUFOR territory zones when `TUM: true`, and structural validity of `mission.yaml` (overlaps the active `FIX-CONVERT-V5-INVALID-YAML` lot — share the YAML-parse check). Exit non-zero on error, with localized messages.

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| VALIDATE-001 | `validate` command + `veaf_libs.mission_validator`: mission.yaml syntax/semantics (reusing non-aborting `check_yaml_syntax`/`collect_module_issues`), custom_scripts existence, declared-group presence, presets/waypoints aircraft presence (coarse), TUM zone prerequisite; `--strict`; localized FR/EN output; tests; maker-guide docs | `veaf_tools/commands/validate.py`, `veaf_libs/mission_validator.py`, `veaf_libs/yaml_validator.py`, `test/python/`, `doc/`, `CHANGELOG.md` | feat | ✅ |
