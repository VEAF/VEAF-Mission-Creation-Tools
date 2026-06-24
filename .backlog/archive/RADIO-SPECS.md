# Lot RADIO-SPECS — DCS radio frequency validation in inject-presets

Status: ✅ done

**Goal**: Extract DCS aircraft radio frequency specs from `dcs-lua-datamine`, bundle them as a YAML data file, validate preset frequencies at inject time, and publish a human-readable reference doc.
**Branch**: `feature/radio-specs-validation`

| # | Ticket | Type | Effort | Status |
|---|--------|------|--------|--------|
| RADIO-001 | Extraction script: fetch `panelRadio` from dcs-lua-datamine and generate `dcs-radio-specs.yaml` | feat | 45 min | ✅ |
| RADIO-002 | Bundle `dcs-radio-specs.yaml` as package data; load via `importlib.resources` | feat | 15 min | ✅ |
| RADIO-003 | `RadioFrequencyValidator`: validate preset frequencies against aircraft specs, warn on mismatch | feat | 45 min | ✅ |
| RADIO-004 | Integrate validator into `PresetsInjectorWorker.process_groups()` | feat | 20 min | ✅ |
| RADIO-005 | Generate `doc/mission-maker/dcs-radio-specs.md` (human-readable Markdown table) from the YAML | feat | 30 min | ✅ |
| RADIO-006 | Unit tests for validator (valid/invalid frequency, unknown aircraft, partial ranges) | feat | 45 min | ✅ |

**Estimated total: ~3h**
