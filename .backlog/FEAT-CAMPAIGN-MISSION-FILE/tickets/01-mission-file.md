# 01 — `campaign.mission_file` and `mission.date_suffix`

Status: 🔄 in-progress
Type: feature

## What

- `campaign.yaml`: an optional `campaign.mission_file`, a plain file name of ASCII letters, digits, dashes and underscores, with no extension or `.miz`. `campaign validate` refuses any other value, and refuses the key on a multi-mission campaign.
- `campaign next`: when the key is set, the mission's name is that value without its `.miz`, and `mission.yaml` gets `mission.date_suffix: false`; without the key, the name is `mission_name()`'s and `date_suffix` is removed.
- `mission build`: a `mission.yaml` with `mission.date_suffix: false` builds `<name>.miz` in the mission folder, with no `_AAAAMMJJ`. Every other mission keeps its date.

## Done when

- Tests for the parsing, the name, the setting written and removed, and the build's file name.
- `PERSISTENT_CAMPAIGN.md` / `.en.md` and `MISSION_YAML_REFERENCE.md` / `.en.md` describe the two keys; CHANGELOG entry; the Python quality gate passes.
