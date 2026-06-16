# TEST PLAN — Post-DCS-update verification (Lot DCS-UPDATE-VERIFY)

> A DCS World update landed. This plan re-verifies the maximum of things the
> toolchain depends on: every DCS-derived datum (design-time) **and** the in-game
> runtime behaviour. Each item is journaled **remark → analysis → fix**.

## Key insight — where our DCS data comes from

Almost every DCS-derived datum is generated from the **Quaggles `dcs-lua-datamine`**
repository at a **pinned `DATAMINE_REF`** (`veaf_build/dcs_data/datamine.py`), *not*
from the local DCS install. So a DCS update does **not** automatically change our
committed data — only bumping `DATAMINE_REF` (after the datamine catches up to the
new DCS version) does. The weekly `dcs-data-drift.yml` workflow auto-opens a bump PR
when upstream moves.

**Exception — install-dependent, NOT CI-guarded**: `airdromes.yaml`
(`veaf_libs/data/`) is generated from the local install's
`Mods/terrains/<map>/Beacons.lua`. A DCS update that adds/changes maps can stale it.

### DCS-derived artifacts (quick map)

| Artifact | Source | Generator | Consumers |
|----------|--------|-----------|-----------|
| `veaf_libs/data/dcs-countries.yaml` | datamine `_G/db/Countries` | `update-dcs-data --countries` | aircrafts_injector, coalition_placeholder (`country_id_for_name`) |
| `veaf_libs/data/dcsUnits.yaml` + `src/scripts/veaf/dcsUnits.lua` | datamine `_G/db/Units` | `update-dcs-data --units` | warehouses_injector (category), runtime Lua (`veafUnits`, spawn, skynet) |
| `presets_injector/data/dcs-radio-specs.yaml` | datamine Units (+ manual overlays) | `update-dcs-data --radio` | presets_injector (frequency ranges) |
| `veaf_libs/data/airdromes.yaml` | **local install** `Mods/terrains/*/Beacons.lua` | `update-dcs-data --airdromes --dcs-path <DCS>` | dynamic-slot warehouse wiring (`airdrome_id_for_name`) |

---

## Track 1 — Design-time (data & build)

### D1 — Datamine drift check ✅
- **Remark**: is the pinned `DATAMINE_REF` still current vs upstream?
- **Result**: pinned `dc7d15e8e34150441b109346eea4ca18eb0104a7` ≠ upstream HEAD
  `75f5aaafa3777ef1be0e13d3aee3900236faff45` → the datamine **has** moved. No
  auto-bump PR is open yet (the weekly workflow hasn't fired since the drift).
- **Analysis**: drift exists but is small (see D2 preview) and the datamine is a
  third-party dump that typically **lags** official DCS releases — it almost
  certainly does not yet reflect the just-installed DCS version. No action forced.

### D2 — Regenerate countries + units, assert no drift ✅
- **Remark**: are the committed data files consistent with the pinned ref, and does
  the generator still run?
- **Result**: `veaf-build update-dcs-data --countries --units` → 92 countries, 868
  units; `git diff` **clean**. Committed data matches the pin.
- **Preview (reverted)**: regenerating at the upstream HEAD would change only
  **+3 units** (868 → 871) and one country field — confirming the upstream drift is
  tiny and unlikely to be the new DCS content. A bump remains a separate decision
  (owned by the `dcs-data-drift.yml` auto-PR), not part of this campaign.

### D5 — DCS-data tests ✅
- **Result**: `pytest test/python/veaf_build/test_dcs_data_* test/python/veaf_libs/test_dcs_*`
  → **51 passed**. Parsing + consumers green against committed data.

### D3 — Airdromes (install-dependent) ✅ — found a real impact
- **Remark**: airdromes come from the local install; did the DCS update change them?
- **Result**: `veaf-build update-dcs-data --airdromes --dcs-path "c:/jeux/DCS World"`
  (7 terrains installed) → **+6 Syria airfields** the committed table was missing:
  `Cukurova`, `Diyarbakir`, `Hatzerim`, `Konya`, `Nevatim`, `Teyman` (Israeli/Turkish
  bases from the Syria-map expansion). Now 199 airfields. Tests:
  `test_dcs_data_airdromes` + `test_dcs_airdromes` → **13 passed**.
- **Analysis**: the **only** DCS-derived datum actually impacted by this update —
  expected, since airdromes are the sole install-dependent, non-CI-guarded artifact.
  Before this refresh, `airdrome_id_for_name()` could not resolve those 6 bases, so a
  dynamic-slot warehouse referencing one would **silently fail to wire** (airbase
  falls back to default slots, no error).
- **Fix**: regenerated `airdromes.yaml` committed.

### D4 — Radio specs ⬜ — deferred
- Only needed if `DATAMINE_REF` is bumped. `--radio` overwrites the manual
  `dcs_rejects_on_load` overlays, which must be re-applied afterward. Out of scope
  unless a bump happens.

---

## Track 2 — Runtime / in-game (updated DCS) — David

Load a freshly built mission in the updated DCS and check `dcs.log`
(`C:\Users\David\Saved Games\DCS\Logs\dcs.log`).

| # | Check | How | Result |
|---|-------|-----|--------|
| R0 | custom_scripts loads in **static** (PR #476) | `FgTest.lua` line in `dcs.log` | ⬜ |
| R1 | Mission loads without new errors | no new `ERROR` in `dcs.log` | ⬜ |
| R2 | VEAF scripts load (static **and** dynamic) | `STATIC/DYNAMIC … scripts loading`, `initialize` | ⬜ |
| R3 | F10 VEAF radio menu + `_spawn`/`_cas`/aliases | in game | ⬜ |
| R4 | ME save round-trip in the new DCS | reopen/save the `.miz`, reload OK | ⬜ |
| R5 | Dynamic Slots offered (warehouse `linkDynTempl`) | dynamic-slot aircraft selectable | ⬜ |
| R6 | Presets / waypoints: mission **saves** | no "Invalid frequency" / "Route has no locked time" | ⬜ |
| R7 | `convert-v5` on a `.miz` saved by the **new** ME | no read crash (mission format may have changed) | ⬜ |

> Journal anything that breaks here as a new remark → analysis → fix entry; fixes go
> on `feature/dcs-update-verify`, one PR at the end.
