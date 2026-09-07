# 01 — Extraction stops handing back the build's injected Lua

Status: ✅ done

Type: fix · Files: `mission_tools/mission_constants.py`,
`mission_extractor/mission_extractor_worker.py`, `test/python/mission_extractor/`

## The defect

`MissionExtractorWorker.extract_mission` removes the VEAF, legacy and community scripts by
name, then moves every other `l10n/DEFAULT/*.lua` into `src/scripts/`. A file the build
injected through a `VEAF_MapKey_*` map resource matches neither list, so it is moved — and
becomes a source of the mission it came out of.

## The fix

Drive it from the mission's own `mapResource` rather than from a list of names: every
`VEAF_MapKey_*` entry pointing at a `.lua` file names something this build generated. That
covers the two artifacts of today and any added later without another edit here.

Keep a small set of known names beside it (`GENERATED_LUA_ARTIFACTS`) as the second half of
the union, for the mission whose map resource was rewritten by hand or by a third-party
tool — and because ticket 02 needs those names anyway, where no `mapResource` exists to
consult.

Restricted to `.lua` on purpose: the sounds and images injected under the same prefix are
not moved into `src/scripts/` by the glob, so they are none of this ticket's business.

## Definition of done

- [x] A `.miz` carrying `veaf-spawn-data.lua` + `VEAF_MapKey_SpawnData` extracts to a folder
      with **no** `src/scripts/veaf-spawn-data.lua`
- [x] Same for `dcs-bridge.lua` / `VEAF_MapKey_DcsBridge`
- [x] A `.lua` named by a **non-VEAF** map-resource key is still extracted (we strip our own
      output, not the mission maker's scripts)
- [x] A `.lua` in `l10n/DEFAULT` referenced by no map-resource key at all is still extracted
- [x] An artifact whose map-resource key is missing is stripped anyway, on its name
- [x] The file does not survive in `src/mission/` either — the copy that feeds the next build
