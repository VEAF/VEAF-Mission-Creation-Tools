# 04 — Every scaffolded mission starts with CTLD's sample `extract` and `logistic` names

Status: ✅ done — 2026-09-29
Type: fix (chore)
Files: `src/python/veaf-tools/veaf_libs/ctld_config.py` (`VEAF_CONFIG_OVERRIDES`,
`apply_veaf_overrides`, `merge_veaf_logistics`), tests

## Origin

private1's `dcs.log`, GermanyCW-v6, 2026-09-28. `FEAT-CTLD-AIRBASE-LOGISTICS` already recorded the
`logistic` half as out of scope, "it wants a chore of its own"; nobody opened it, and the `extract`
half was not mentioned.

## Measured

- At mission start: 25 × `CTLDCoreManager: INIT-E - extractableGroup 'extract#' not found, skipped`
  and 10 × `CTLDZoneManager: logisticUnits 'logistic#' not found in mission`.
- The names come from CTLD's own catalogue (`CTLD.lua`, `extractableGroups: extract1 … extract25`
  and `logisticUnits: logistic1 … logistic10`), which `ctld_config.py` copies whole into a new
  mission's `ctld-config.yaml`; `VEAF_CONFIG_OVERRIDES` touches neither list. No VEAF mission names
  a group `extract1` or a unit `logistic1`.
- CTLD reads the snapshot with no merge ("a missing list is an intentional removal"), so an empty
  list in the mission is honoured. Its YAML parser reads `[]` as an empty table
  (`CTLDConfig.scalar`) but does **not** strip a trailing comment: `key: []   # note` is read as the
  string `"[]   # note"`. Measured on GermanyCW-v6 by running the parser on the generated
  `CTLD_userConfig.lua`.

Worked around in the mission by emptying both lists, the comment on its own line.

## Done when

- A scaffolded mission gets `extractableGroups: []` and `logisticUnits: []`, through the VEAF
  overrides, without disturbing what `merge_veaf_logistics` adds when `manage_logistics` is on.
- No comment written by the tools ever sits at the end of a value line in `ctld-config.yaml`.
- `validate_mission` warns on an `extractableGroups` / `logisticUnits` name the mission does not
  hold, so existing missions are caught.
- Tests.

## Done — 2026-09-29

- `ctld_config.VEAF_EMPTIED_LISTS`, applied by `apply_veaf_overrides` only: kept apart from
  `VEAF_CONFIG_OVERRIDES` because the build **merges** that one into a mission's lists, and a
  maker's own `extractableGroups` must survive. Tested against the vendored `CTLD.lua`, through the
  scaffold and the build's merge.
- The tools write no comment into `ctld-config.yaml`: the `[] # note` read as a string came from
  the hand-written workaround. The test asserts no `#` on either line.
- `validate` warns on a name in either list that the mission holds as neither a group nor a unit
  (`validate.ctld_name_not_in_mission`, catalogued in `build-messages/modules`).
