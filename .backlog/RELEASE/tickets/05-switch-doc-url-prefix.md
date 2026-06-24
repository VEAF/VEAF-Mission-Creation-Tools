# REL-005 — switch doc URL prefix from `/dev/` to `/latest/`

Status: ⬜ ready
Type: chore
Files: `v5_converter.py`, `src/defaults/mission-folder/mission.yaml`

## What to build

Change the doc URL prefix from `/dev/` to `/latest/` in `v5_converter.py` (`DOC_BASE`,
`_DOC_BASE`) and `src/defaults/mission-folder/mission.yaml`.

## Acceptance criteria

- [ ] `DOC_BASE` / `_DOC_BASE` in `v5_converter.py` use `/latest/`
- [ ] `src/defaults/mission-folder/mission.yaml` doc URL uses `/latest/`

## Blocked by

REL-003
