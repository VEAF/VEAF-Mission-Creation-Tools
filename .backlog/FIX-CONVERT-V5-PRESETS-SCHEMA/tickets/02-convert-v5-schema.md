# 02 — Detect and convert a v5-schema presets.yaml

Status: ⬜ ready
Type: fix
Files: `src/python/veaf-tools/mission_builder/v5_converter.py`

## Why the file slips through

`V6_PIPELINE_CANDIDATES["presets"] = ["src/presets.yaml"]` is the **target** the converter writes
when generating presets from a v5 `settings.lua`. When a file is already there, it is left alone —
which is right when it is a v6 file, and wrong when it is a v5 one that happens to share the name
and the file format.

The schema difference is **not** a single level — see the drift table in the PRD. It starts as one:

```yaml
presets_assignments:
  coalitions:      # v5 only
    blue: …
```

## Tasks

- [ ] **Diff the two schemas first, in full.** Three renames were found by hand before the walk
      was abandoned (`presets_assignments.coalitions`, `presets_definition` → `presets_collection`,
      inline `radios` → `radios_collection`) and there is no reason to think that is all of them.
      Write the mapping down before writing the converter.
- [ ] Detect the v5 schema by structure, **not** by filename: a `coalitions` key directly under
      `presets_assignments`. A filename says nothing about content, which is the whole reason this
      slipped past.
- [ ] Decide and record which of the two: rewrite it in place to the v6 shape, or move it aside to
      `presets.v5.yaml` and regenerate from `settings.lua`. `_CLEANUP_SRC_KNOWN` already knows the
      `presets.v5.yaml` name, which suggests the second was the intent at some point — check the
      history rather than assuming.
- [ ] Report it in the conversion report like any other converted artifact. A silent pass is what
      produced this bug.
- [ ] Test with the repository's **own demo mission**, which is a real v5 fixture and reproduced
      this exactly.

## Watch out

`test/veaf-tools/demo-mission/` must stay **v5**: `test_config_migrator.py` uses its
`missionConfig.lua` as a migration fixture (`TestIntegrationDemoMission`). Convert a copy, never
the fixture — `convert-v5` works in place.
