# 02 — Convert the demo to v6, and make it demonstrate v6

Status: ✅ done 2026-08-15 — converted to v6, validates clean, builds; demonstrates a delayed custom script + YAML combat zones/operation; validator SANCTUARY group-name fix.
Type: feat
Files: `test/veaf-tools/demo-mission/**`

## The conversion

`veaf-tools convert v5` on the folder — it is in-place and promotes `src/mission/` too. Then read the
generated `mission.yaml` rather than trusting it: this repository's own history is a list of things
that conversion got subtly wrong (`FIX-CONVERT-V5-PRESETS`, `FIX-CONVERT-V5-OPERATION-SUBZONES`,
`FIX-BRIEFING-MULTILINE`, `FIX-CONVERT-SPAWNABLES-FLAT-FORMAT`).

Rebuild and keep a built `.miz` where `test_edit_zone.py` expects one.

## Then make it worth opening

A converted v5 mission demonstrates v5 with v6 syntax. The demo should show at least one thing a v5
mission could not declare — pick from what shipped since:

- a `modules:` block with a third-party module and its sidecar config;
- a combat zone declared in YAML rather than built by hand;
- radio presets in the **preset-plan** model, which is the whole point of `FEAT-RADIO-PRESET-PROJECTION`;
- `custom_scripts:` with a `delay_seconds:`, the feature `FEAT-CUSTOM-SCRIPT-LOAD-DELAY` added and
  which is invisible in every shipped example.

Say in the mission's own README which v6 feature it is there to show, so the next person does not have
to diff it against a v5 mission to find out.

## Acceptance criteria

- [ ] `mission.yaml` present; `veaf-tools mission validate` clean; `mission build` produces a `.miz`.
- [ ] At least one v6-only feature declared, and named in the folder's README.
- [ ] `test_edit_zone.py` still finds its `.miz`.
- [ ] Full Python gate green.
