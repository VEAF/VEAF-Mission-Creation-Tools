# 03 — The four training versions, built with the night's

Status: ⬜ ready

When `mission.yaml` holds a `training:` block, `veaf-tools build` produces the night's `<mission>.miz` and four more: `_TRAINING_A2G`, `_TRAINING_CAP`, `_TRAINING_SEAD`, `_TRAINING_ALL`.
Each is a profile **derived** from the block at build time — never written into `mission.yaml` — applying the PRD's rule table with ticket 02's `remove_groups`, `zone_edits` and the QRA and CAP modules' settings.

## Done when

- One parametrised test sweeps the whole rule table: every `kind` × every version, presence and absence checked in the built `.miz` (groups in the mission table, combat zones, QRA definitions and on-demand CAPs in the generated configuration).
- `a2g_target` on a combat zone removes the zone's groups and its radio menu entry from the CAP and SEAD versions, not only its activation.
- The CAP version forces the night's QRA definitions on; a mission with no QRA builds the CAP version with a warning saying none exists.
- The briefing texts and pictures are identical in the five `.miz` (test).
- The night's `.miz` is byte-identical to the same folder built without the `training:` block.
- A `training:` block next to `build_variants:` is refused with a message naming both keys (PRD, out of scope).
- `build_mission` (MCP) reports the five paths.
