# Lot FIX-MISSIONYAML-MISSION-SECTION — `mission:` block mislabeled + migrated-field provenance

Status: ✅ done

**Goal**: The generated `mission.yaml` puts `silence_atc_on_all_airbases` (a mission-wide **behaviour** toggle) under a section **labeled "Mission identity"** (comment: *"name, export path, and era"*), which is misleading (Tripack: "pourquoi dans le chapitre identité ?"). The field correctly lives in the `mission:` block — that's where the generator reads mission-level settings (`lua_config_generator.py:824` → `veaf.silenceAtcOnAllAirbases()`), alongside `era`/`language` which are also not pure identity. Decision (David): **keep `silence_atc` under `mission:`** (the `settings:` block emits `veaf.config.KEY = value`, not a function call, so it doesn't fit; moving it would fragment mission-level settings and churn the generator/defaults/doc for no gain) — the real defect is the **label**. **(1)** Broaden the `mission:` section label/comment so it reads as mission **settings** (identity **+** options), and add a short inline comment on `silence_atc_on_all_airbases`. **(2)** `convert-v5` annotates **provenance** on migrated fields — a `# migrated from veaf.silenceAtcOnAllAirbases()` comment — so makers understand "how it got there" (CONVERT-FIDELITY-003 emits it only when the v5 source had an active, non-commented call).

**Branch**: `fix/missionyaml-mission-section` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| FIX-MISSIONYAML-MISSION-SECTION-001 | Broaden the `mission:` section header/comment (no longer just "identity"), add an inline comment on `silence_atc_on_all_airbases`, and have `convert-v5` annotate the provenance of migrated fields. Keep `silence_atc` under `mission:`. Lockstep: update `src/defaults/mission-folder/mission.yaml` and the doc. | `veaf_libs/lua_config_generator.py`, `veaf_libs/locales/*.json`, `mission_builder/v5_converter.py`, `src/defaults/mission-folder/mission.yaml`, `doc/`, `test/python/` | fix | ✅ (#502) |
