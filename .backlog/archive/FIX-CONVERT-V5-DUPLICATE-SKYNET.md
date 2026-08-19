# FIX-CONVERT-V5-DUPLICATE-SKYNET — convert-v5 writes the SKYNET module key twice

Status: ✅ done — 2026-08-15

Origin: spotted on the demonstration mission while migrating it to v6
(`MIGRATE-DEMO-MISSION-V6`): the generated `mission.yaml` carried two `SKYNET:` keys in its
`modules:` block, a duplicate YAML mapping key removed by hand at the time. This lot fixes the
generator so a fresh conversion cannot produce it again.

## The measurement

`V5Converter._build_mission_yaml` emits enabled modules from two places:

- the **category loop** (`v5_converter.py`, `for category, cat_mods in MODULE_CATEGORIES.items()`),
  where `MODULE_CATEGORIES["External"] == ["SKYNET", "SKYNET_MONITOR"]`, writes a bare
  `SKYNET: true` under the `# External` header;
- the **community-scripts section**, which iterates `get_community_script_files()` (SKYNET is one
  of them) and writes a `SKYNET:` block carrying its config (`include_red_in_radio`, `debug_red`,
  `include_blue_in_radio`, `debug_blue`).

SKYNET is therefore both a module *and* a community script, and an enabled SKYNET is emitted by
both — two `SKYNET:` keys in one mapping. A YAML reader keeps the last and silently drops the
first, so whichever ordering wins, one of the two intents (the config block, or the bare enable)
is lost without a word.

## The fix, at the cause

The community section is authoritative for SKYNET: it is the only one that carries the config. So
the category loop **excludes any module whose id is also a community script**
(`community_ids_upper`), leaving `SKYNET_MONITOR` — a module, not a community script — untouched
under `# External`. To keep the bare-enable intent when there is no config, the community
section's fallback now reads `detected or upper in enabled_by_id`, so a SKYNET enabled as a module
still renders `true` even when its `.lua` is not bundled.

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | Emit SKYNET once | ✅ |

## Definition of Done

- A generated `mission.yaml` with SKYNET enabled contains exactly one `SKYNET:` key.
- The surviving entry is the config block when a config exists; `true` otherwise.
- `SKYNET_MONITOR` still appears under `# External`.
- `pytest` + ruff + mypy green.

---

## 01 — Emit SKYNET once

Status: ✅ done

### Problem

`V5Converter._build_mission_yaml` emits SKYNET twice when it is enabled: once as a bare
`SKYNET: true` from the `MODULE_CATEGORIES["External"]` category loop, once as a `SKYNET:` config
block from the community-scripts section. The result is a duplicate YAML mapping key in the
`modules:` block; a reader keeps only the last, silently dropping the other.

### Fix

- In the category loop, skip module ids that are also community scripts
  (`community_ids_upper = {s["id"].upper() for s in get_community_script_files()}`), so the
  community section is the single, authoritative emitter for SKYNET. `SKYNET_MONITOR` is not a
  community script and stays under `# External`.
- In the community section's fallback branch, treat a community script that is also an enabled
  module as enabled (`detected or upper in enabled_by_id`), so a SKYNET enabled without config or
  bundled `.lua` still renders `true`.

### Tests

`test/python/mission_builder/test_convert_v5_skynet_no_duplicate.py`:

- SKYNET enabled with config → exactly one `SKYNET:` key.
- The surviving entry is the config block (`include_red_in_radio` present, `enabled: true`).
- SKYNET enabled without config → still one key, and it reads `true`.
