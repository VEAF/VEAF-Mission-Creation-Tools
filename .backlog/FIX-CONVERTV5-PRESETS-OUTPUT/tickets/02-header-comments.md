# 02 — Header comments on generated presets files

Status: ✅ done
Type: fix

## Tasks

- [ ] `_yaml_dump` gains an optional `header: str | None` (comment block written
      before the YAML body), without changing its other callers.
- [ ] Plan (`presets.yaml`) header: explain `channel_lists` (packer-projected plan),
      `channels_collection` (alias resolution), and the faithful `presets.v5.yaml`
      sibling; "generated — do not edit by hand" note.
- [ ] Faithful (`presets.v5.yaml`) header: short "raw iso-functional copy, reference /
      rollback, NOT loaded by the build".
- [ ] Localize the headers (FR/EN via `t()`), consistent with other generated files.

## Definition of Done

- Both generated files carry a clear header; Markdown and YAML still parse; tests green.
