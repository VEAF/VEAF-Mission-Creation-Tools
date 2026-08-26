---
Status: ✅ done
---

# 02 — Merge the VEAF types when injecting, without touching the maker's file

## Where

`MissionBuilderWorker._build_ctld_user_config` (`mission_builder/mission_builder_worker.py`) reads
`ctld-config.yaml` and injects it as a Lua long-bracket string. Today it is passed through
verbatim; with the flag on, the YAML is parsed, merged and re-serialised **on the way into the
`.miz`**. The file in the mission folder is never rewritten — it stays the maker's.

## Do

- Factor a `merge_veaf_logistics(catalogue) -> str` into `veaf_libs/ctld_config.py`, next to
  `apply_veaf_overrides`, sharing `VEAF_CONFIG_OVERRIDES` as the single source of the type list.
  Round-trip through ruamel exactly as `apply_veaf_overrides` does: comments, key order and
  formatting must survive, since the maker reads this file in `ctld-tools`.
- Union semantics, order-preserving: the mission's own entries first, VEAF's appended if absent.
  No duplicates.
- A key the engine's catalogue does not define is **skipped, not created** — same rule
  `apply_veaf_overrides` already applies, for the same reason (an older vendored engine).
- Header comment in the generated `CTLD_userConfig.lua` naming the types VEAF added, or stating
  that automatic management is off.

## Done when

The three cases of the PRD table are asserted against the produced `CTLD_userConfig.lua`, not
against the helper in isolation — the defect being fixed is precisely that the wiring, not the
helper, was missing. Round-tripping a catalogue with comments leaves them in place.
