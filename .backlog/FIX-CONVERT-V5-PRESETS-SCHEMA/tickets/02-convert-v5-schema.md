# 02 — Detect and convert a v5-schema presets.yaml

Status: ✅ done — 2026-08-10
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

## Done

`presets_schema_migrator.py` holds the mapping and the detection; `convert-v5` gained a
`needs_schema_migration` flag distinct from `needs_conversion` — the file is the right file, in the
right place, in the right format, and only its inner layout is v5.

### The schema diff, in full, before any code was written

| v5 | v6 |
|---|---|
| `presets_definition:` | `presets_collection:` |
| `presets_definition.<preset>` | `presets_collection.<collection>.<preset>` |
| a preset's `radios.<slot>` holds the definition inline | it holds the **name** of a radio in `radios_collection` |
| channel keys `channel_01`, `channel_02` | integer keys `1`, `2` |
| a channel's `name` | a channel's `title` |
| `presets_assignments.coalitions.<side>` | `presets_assignments.<side>` |

Six, not the one the ticket assumed. Nothing had to be invented: v6 accepts `{freq, title, mod}`, so
the frequencies carry over verbatim and no `channels_collection` is needed.

### What the acceptance test caught

A radio's `type:` is **mandatory** in v6 and v5 never wrote it. Reading the code suggested otherwise
— it is only consulted to resolve a channel *alias*, which converted channels do not have — so the
first version left it out. Running the migrated demo mission through the real `PresetsManager`
refused it on the spot. It is now inferred from the frequencies, and a radio whose channels straddle
two bands says so rather than choosing in silence.

### The fixture warning was honoured

`test/veaf-tools/demo-mission/` is still v5, verified by a test that asserts it. The end-to-end run
converted a **copy** in a scratch folder; `git status` on the fixture is clean.
