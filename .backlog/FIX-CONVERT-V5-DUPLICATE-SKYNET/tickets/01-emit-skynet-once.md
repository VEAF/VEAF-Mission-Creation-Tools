# 01 — Emit SKYNET once

Status: ✅ done

## Problem

`V5Converter._build_mission_yaml` emits SKYNET twice when it is enabled: once as a bare
`SKYNET: true` from the `MODULE_CATEGORIES["External"]` category loop, once as a `SKYNET:` config
block from the community-scripts section. The result is a duplicate YAML mapping key in the
`modules:` block; a reader keeps only the last, silently dropping the other.

## Fix

- In the category loop, skip module ids that are also community scripts
  (`community_ids_upper = {s["id"].upper() for s in get_community_script_files()}`), so the
  community section is the single, authoritative emitter for SKYNET. `SKYNET_MONITOR` is not a
  community script and stays under `# External`.
- In the community section's fallback branch, treat a community script that is also an enabled
  module as enabled (`detected or upper in enabled_by_id`), so a SKYNET enabled without config or
  bundled `.lua` still renders `true`.

## Tests

`test/python/mission_builder/test_convert_v5_skynet_no_duplicate.py`:

- SKYNET enabled with config → exactly one `SKYNET:` key.
- The surviving entry is the config block (`include_red_in_radio` present, `enabled: true`).
- SKYNET enabled without config → still one key, and it reads `true`.
