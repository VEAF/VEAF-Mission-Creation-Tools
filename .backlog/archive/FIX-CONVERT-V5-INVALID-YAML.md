# Lot FIX-CONVERT-V5-INVALID-YAML — convert-v5 emits unparseable mission.yaml

Status: ✅ done

**Goal**: on a freshly converted v5 mission, `build` aborts with a YAML syntax error in the generated `mission.yaml` (observed: "Erreur de syntaxe dans mission.yaml, ligne 308, colonne 7 — l'erreur débute vers la ligne 212, colonne 7", indentation). `convert-v5` is producing structurally invalid YAML. Reproduce, find the offending emitted block (indentation/escaping around the reported lines), fix the generator, and add a regression test that the generated mission.yaml always parses.

**Done**: reproduced on the reporting mission (`Training-Syrie`) — exact error `expected <block end>, but found '?'` at line 212/308. Root cause in `_emit_qra_definitions`: a QRA defined with `start = false` in v5 emitted `start: false` via the `converter.yaml.qra.start_comment` translation, which **hard-coded a 6-space indent** — placing the field at the `definitions:` sequence level instead of inside its `- name:` item (8-space `field` indent like every other QRA field). The misaligned key broke the block sequence. Fixed by emitting `f"{field}start: false  {t(...)}"` and reducing the FR/EN translation to the comment only. (No twin bug — `start_comment` was the only i18n value hard-coding YAML indentation.) Verified: `Training-Syrie` now parses; 4 regression tests assert the QRA block parses (single/multiple disabled defs, correct indent, `start:true` emits nothing).

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| FIX-CONVERT-V5-INVALID-YAML-001 | Reproduce + fix the indentation bug in the convert-v5 mission.yaml emitter (QRA `start: false` indent via hard-coded i18n); regression tests that output parses | `mission_builder/v5_converter.py`, `veaf_libs/locales/{en,fr}.json`, `test/python/mission_builder/test_convert_v5_qra_yaml.py` | fix | ✅ |
