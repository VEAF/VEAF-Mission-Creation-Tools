# CHORE-VENDOR-CTLD-RC12 — take CTLD 2.0.0-rc12

Status: ✅ done — 2026-10-03 (PR #1051)

`published-v2.0.0-rc12` shipped on 2026-09-24; the weekly drift watch reported it on #618
(`published-v2.0.0-rc11` → `published-v2.0.0-rc12`). A routine verbatim sync, done the way
`CHORE-VENDOR-CTLD-RC11` did it.

## What rc12 changes in the engine

The release notes are mostly about `ctld-tools`, which this repository does not vendor. What lands
in `CTLD.lua` is small — the real diff is **91 lines**:

- **A reoccupied slot no longer inherits the previous pilot's flight state** (VEAF/CTLD#156):
  `_forgetPlayer` now also drops the flight-state debounce record of the departed unit.
- **Extraction zones by naming convention**: a trigger zone named `EXZ_<name>_<flag>_<smoke>` is
  discovered at start and created through the same `createExtractZone` path as the scripted API.
  A malformed name is reported in the startup report, not raised.
- **The embedded configuration catalogue changes** — the first sync since ADR 0016 where it does:
  the UH-1H loses whole-vehicle transport (`canTransportWholeVehicle: false`, troops 8 → 10), the
  Mi-8MT gains it (`maxVehicleWeight: 3000`, a loadable-vehicle list per side,
  `maxWholeVehiclesOnboard: 1`).
- i18n: one new key in four languages, translation version 1.18 → 1.19.

## Who sees the configuration change

The catalogue is read from the vendored file at build time (`veaf_libs/ctld_config.py`); no copy
of it lives in this repository, so nothing here needs updating and §9.7's defaults lockstep does
not apply. The effect on a mission depends on its `ctld-config.yaml`:

| mission | effect |
|---|---|
| no `ctld-config.yaml` | CTLD runs on its embedded defaults → the new UH-1H / Mi-8MT values |
| scaffolded by `prepare` from now on | the new catalogue is copied in → the new values |
| existing `ctld-config.yaml` | never overwritten by `prepare` → keeps the values it holds |

## Measured

- The vendored file is the published asset with its line endings normalised: the download arrives
  in CRLF and the vendored copy is LF, as for rc11. SHA-256 of the vendored file `c95430e94058dd6e…`,
  1 196 345 bytes; `ctld.VERSION` reads `2.0.0-rc12`.
- `poetry run test-lua`: **52 suites green**, `test_community_scripts_load.lua` included — it
  executes the vendored artefact under the DCS mocks rather than parsing it (the gate added after
  rc8 shipped dead, #957).
- `poetry run check-vendored`: CTLD up to date. One other artefact reports drift, **dcs-schema**
  (`v0.3.5` → `v0.4.0`), outside this lot.

## Definition of done

- `src/scripts/community/CTLD.lua` is the rc12 asset verbatim, in LF.
- `vendored.yaml` pins `2.0.0-rc12` and watches `published-v2.0.0-rc12`.
- The whole Lua suite green, the community load gate included.
- `CHANGELOG.md` entry under `[Unreleased]`.
- No version bump — §9.5.

## Not claimed

The file has not been flown in DCS from this repository. The evidence stops at "it loads and
initialises under the mocks".

## Out of scope

- The dcs-schema drift: a documentation/stub reference, not a shipped script; it gets its own sync.
- Closing #618 by hand: the watcher closes it when nothing drifts any more — which the dcs-schema
  drift will prevent until that one is taken too.

## Former index entry

The row this lot had in `.backlog/README.md` until the index was split into short summaries (CHORE-BACKLOG-INDEX-SPLIT, 2026-10-03), kept verbatim.

**take CTLD `2.0.0-rc12`, reported by the drift watch on #618.** Verbatim, LF-normalised; the real diff is 91 lines. A reoccupied slot no longer inherits the previous pilot's flight state, `EXZ_<name>_<flag>_<smoke>` trigger zones become extraction zones, and — first time since ADR 0016 — the embedded configuration catalogue moves: the UH-1H stops carrying whole vehicles (troops 8 → 10), the Mi-8MT starts. Missions with no `ctld-config.yaml` or scaffolded from now on get it; an existing `ctld-config.yaml` keeps its values
