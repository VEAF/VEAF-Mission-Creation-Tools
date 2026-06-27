# TDM-001 — vendor the DCS API schema (pinned)

Status: ✅ done
Type: chore
Files: `src/python/veaf-tools/veaf_libs/data/dcs-schema/` (json + LICENSE + NOTICE)

## What to build

Commit a frozen copy of `dcs-world-api-schema.json` from `dcs-world-schema` release
**v0.3.5**, with the upstream **MIT `LICENSE`** and a `NOTICE` recording the tag, source
URL, and fetch date.

## Acceptance criteria

- [x] `dcs-world-api-schema.json` (v0.3.5) committed under `veaf_libs/data/dcs-schema/`
- [x] Upstream MIT `LICENSE` + a `NOTICE` (tag / URL / fetch date) alongside
- [x] Packaged like the other `veaf_libs/data/` assets (same dir; this is a `poetry run` dev/CI tool, not bundled in the exe — consistent with `dcsUnits.yaml`, also absent from the `.spec`)

## Blocked by

—
