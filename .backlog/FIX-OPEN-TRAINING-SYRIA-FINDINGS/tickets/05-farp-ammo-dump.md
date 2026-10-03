# 05 — add_farp places its ammunition dump

Status: ✅ done

Files: `veaf_mission_mcp/add_farp.py`, `veaf_mission_mcp/actions.py`, `.prompts/new-open-training-mission.*.md`, tests.

## What happened

The Open Training prompt says a FARP is complete with a `FARP Ammo Dump Coating` static beside it (CTLD
`manage_logistics` turns it into a loading point). `add_farp` places the heliport, its radio and its
warehouse entry, not the dump: each of the three Syria FARPs needed a separate `add_group` call.

## Done when

- `add_farp` places the dump by default, same coalition and country, about 60 m from the pad, named
  `<FARP> - Ammo`; `ammo_dump: false` skips it. The result names it.
- The prompt drops the separate step.
