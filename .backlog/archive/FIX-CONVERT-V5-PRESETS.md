# Lot FIX-CONVERT-V5-PRESETS — Per-aircraft radio assignments in convert-v5 presets

Status: ✅ done

**Goal**: Fix `convert-v5` so that per-aircraft radio specificity from `radioSettings` is preserved in the generated `presets.yaml`.

**Branch**: `fix/convert-v5-presets-per-aircraft` → PR #381 → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| CVPRE-001 | Parse `radioSettings` table and detect per-aircraft radio layouts (warbird, VHF-primary, hardcoded) | `v5_pipeline_converters.py` | fix | 30 min | ✅ |
| CVPRE-002 | Auto-assign warbird and VHF-primary aircraft in `presets_assignments`; emit warnings for typePattern and hardcoded entries | `v5_pipeline_converters.py` | fix | 10 min | ✅ |
| CVPRE-003 | Add i18n messages for new warnings; add 28 unit tests | `locales/en.json`, `locales/fr.json`, `test_v5_pipeline_converters.py` | feat | 5 min | ✅ |
| CVPRE-004 | Support regex patterns as `unit_type` keys in `presets_assignments` (exact > pattern > `all`) | `presets_manager.py`, `test_presets.py` | feat | 20 min | ✅ |
