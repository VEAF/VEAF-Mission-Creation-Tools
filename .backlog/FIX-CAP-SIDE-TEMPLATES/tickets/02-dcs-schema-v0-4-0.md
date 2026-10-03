# 02 — vendored DCS schema `v0.4.0`

Status: ✅ done — 2026-10-03 (PR #1052)

The drift watch reports `YoloWingPixie/dcs-world-schema` `v0.3.5` → `v0.4.0` (released 2026-10-02).
Re-download `dcs-world-api-schema.json` and `dcs-world-api.lua` verbatim, bump `vendored.yaml` and the
`NOTICE`.

## Measured

- `audit-dcs-mocks` gives the same report on `v0.3.5` and `v0.4.0`: 0 missing mock, 12 used calls
  absent from the schema, 14 mocks never used.
- Upstream fixed the off-by-one in `types["country.name"]` (YoloWingPixie/dcs-world-schema#22): 92
  names, every one the inverse of `types["country.id"]`. The `NOTICE`, the developer README (FR/EN)
  and the `dcs_mocks.lua` comment said it was broken; they now say it was, until `v0.3.5`.
- `test_vendored_schema_country_ids.py` gains a test asserting the name table is the inverse of the
  id table — it fails on `v0.3.5`, passes on `v0.4.0`.

## Not checked

`v0.4.0` changes types (PascalCase task ids, typed ids). That reaches only LuaLS hints in a
contributor's editor through `.luarc.json`; no CI step reads the annotations.

## What the bump exposed

The support bot's `find_callers` validated only the last dotted segment of a function name, so its
test feeding `convert_fixture(); import os; os.system` searched for `system(`. It stayed green only
while no file in the checkout held that text; `v0.4.0` has one in a comment (`Link 4 system (label
only)`), and the bot's `quality` job went red on this PR. Fixed in `traces.py`: every segment must
be an identifier.
