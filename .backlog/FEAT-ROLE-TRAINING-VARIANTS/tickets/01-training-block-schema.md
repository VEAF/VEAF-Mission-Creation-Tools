# 01 — The `training:` block and its validation

Status: ⬜ ready

A `training:` block in `mission.yaml`, read by the build and checked by `validate_mission`, in the shape the PRD gives.

- `elements[]`: one selector — `groups` (names or `*` patterns on Mission Editor group names), `zone` (a combat zone's `zone_name`), `qra` (a QRA definition's name), `cap_mission` (an on-demand CAP's name) — and a `kind` among `enemy_cap`, `qra`, `sam_lr`, `a2g_target`, `sam_threat`.
- `randomize[]`: a `name`, `replaces` (patterns of the groups the draw stands in for), a `pool` of candidates — `group:` (a Mission Editor group), `command:` (a VEAF `#command` shortcut), `units:` (DCS types and counts) — and `count` and `radius`, each a number or a `min-max` range.
- An optional `at:` on a draw anchors it on a point instead of the replaced groups' positions.

## Done when

- The block parses into a typed model (`models.py` of the worker that owns it), with Google docstrings and full annotations.
- `validate_mission` reports, as errors naming the culprit: a selector matching nothing, an unknown zone, QRA or CAP mission, an unknown `kind`, a group claimed by two kinds, an unknown `command:` alias, an unknown DCS type in `units:`, a `count` larger than the pool, a malformed range.
- A group both in `elements` and in a `randomize.replaces` is an error: a vague element is drawn, not classified.
- The shipped `src/defaults/mission-folder/mission.yaml` carries the block commented out, with one line per key (CLAUDE.md §9, defaults lockstep).
- Tests cover every error above, each with a case that passes and one that fails.
