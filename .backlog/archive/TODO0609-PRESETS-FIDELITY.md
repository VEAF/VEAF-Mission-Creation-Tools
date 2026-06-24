# Lot TODO0609-PRESETS-FIDELITY — Iso-functional radio presets conversion

Status: ✅ done

**Goal**: v5 presets encode DCS module quirks (e.g. Mi-24 channel 0 mapped to channel 20 on injection, AJS-37 offsets). The current `convert-v5` loses these. First make conversion iso-functional with the v5 mission; then analyse whether the v6 `presets.yaml` data structure is adequate (the v5 structure may have been better) and propose enriched defaults. Covers todo-2026.06.09 item 13.

**Branch**: `fix/presets-fidelity` → PR → `develop-v6` (13a); follow-up branch for 13b once the spike lands

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| PRESETS-FIDELITY-001 (13a) | Make `convert-v5` produce a `presets.yaml` iso-functional with the v5 mission's presets — preserve per-module channel mappings/offsets (Mi-24 ch0→20, AJS-37, …). Regression tests against real v5 preset fixtures. | `mission_builder/v5_pipeline_converters.py`, `presets_injector/`, `test/python/` | fix | ✅ |
| PRESETS-FIDELITY-002 (13b, spike) | Analyse the v6 `presets.yaml` data structure vs the v5 presets structure; decide whether to redesign it; propose a default `presets.yaml` that accounts for DCS module quirks. Deliverable: reco + tickets. | `presets_injector/`, `src/defaults/mission-folder/src/presets.yaml` | spike | ✅ |
