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
| R0 | custom_scripts loads in **static** (PR #476) | `FgTest.lua` line in `dcs.log` | ✅ `=== VEAF CUSTOM SCRIPT FgTest LOADED (static test) ===` at 12:56 — confirms PR #476 end-to-end in the updated DCS |
| R1 | Mission loads without new errors | no new `ERROR` in `dcs.log` | ⬜ |
| R2 | VEAF scripts load (static **and** dynamic) | `STATIC/DYNAMIC … scripts loading`, `initialize` | ⬜ |
| R3 | F10 VEAF radio menu + `_spawn`/`_cas`/aliases | in game | ✅ functional (2 bugs fixed: R3-BUG, R3-FINDING-2); 1 cosmetic i18n gap spun off (R3-FINDING-3) |
| R4 | ME save round-trip in the new DCS | reopen/save the `.miz`, reload OK | ⬜ |
| R5 | Dynamic Slots offered (warehouse `linkDynTempl`) | dynamic-slot aircraft selectable | ⬜ |
| R6 | Presets / waypoints: mission **saves** | no "Invalid frequency" / "Route has no locked time" | ⬜ |
| R7 | toolchain reads a new-DCS-format mission (`build`/`convert-v5`) | no read/parse crash | ✅ build read a real mission (127-aircraft presets injected, no luadata crash); convert-v5 ran. Found a convert-v5 fidelity bug → spun off (see R7-BUG) |

> Journal anything that breaks here as a new remark → analysis → fix entry; fixes go
> on `feature/dcs-update-verify`, one PR at the end.

### R3-BUG — `_cas` crashes in static: `convertLaserToFreq` is nil 🐞→✅

- **Remark**: `-cas` (alias → `_cas, disperse`) spawned the Red CAS group, then the
  marker handler errored: `[veaf-scripts.lua]:32479: attempt to call field
  'convertLaserToFreq' (a nil value)` (called from `veafCasMission`, building the
  JTAC laser frequency).
- **Analysis**: `veafSpawn.convertLaserToFreq` / `markTextAnalysis` live in
  `veafSpawnParser.lua` (created by the spawn refactor). The **static bundle manifest**
  in `veaf_build/worker.py` listed `veafSpawnCore/Ground/Aircraft/Effects/Spawn.lua`
  but **not** `veafSpawnParser.lua` — so its body was never concatenated into
  `veaf-scripts.lua`. Static/distribution builds therefore lacked those functions
  (`_cas` JTAC + `_spawn` text parsing broke); dynamic dev builds were unaffected
  because the dynamic loader globs every `veaf/*.lua`. Pre-existing distribution bug,
  unrelated to the DCS update — surfaced by the static in-game test.
- **Fix**: added `veafSpawnParser.lua` to the bundle list (after `veafSpawnCore.lua`),
  extracted the list to a module-level `LUA_BUNDLE_SCRIPTS` + `LUA_BUNDLE_EXCLUDED`,
  and added `test_lua_bundle_manifest.py` asserting **every** `veaf/*.lua` on disk is
  bundled or explicitly excluded — so a future split file can never be silently
  dropped again. Verified the rebuilt bundle contains `convertLaserToFreq`.
- **Re-test**: ✅ `_cas` no longer crashes (David, mission rebuilt with the fixed bundle).

### R3-FINDING-2 — `_cas` default AFAC (MQ-9) never spawns: no template shipped 🔍 open

- **Remark**: after the `convertLaserToFreq` fix, `_cas` spawns the CAS group fine but
  logs (INFO, not a crash) `The AFAC aircraft template could not be found for "mq9"` /
  `The CAP aircraft template could not be found for "mq9"`.
- **Analysis**: `veafCasMission` hardcodes spawning an MQ-9 AFAC
  (`veafSpawn.spawnAFAC(..., "mq9", ...)`, veafCasMission.lua:1070). The AFAC is
  resolved among the `veafSpawn-`-prefixed template groups injected from
  `spawnables.yaml`. Neither the **shipped default** spawnables
  (`src/defaults/mission-folder/src/spawnables.yaml`) nor the test mission's own (a
  real-mission export) contains an MQ-9 / AFAC template — both ship **CAP fighters
  only**. So `_cas`'s aerial-JTAC AFAC is silently absent for everyone. Pre-existing
  feature gap, unrelated to the DCS update or the bundle fix; non-fatal (`_cas` still
  works, just without the Reaper).
- **Root cause**: v5→v6 regression. v5 shipped `veafSpawn-MQ-9 - AFAC - JTAC - DRONE`
  in the demo mission; the reworked v6 default spawnables (a different `foxN`-tagged
  CAP set) dropped it. Confirmed via a diff of the v5 demo vs the v6 default templates.
- **Fix** (David: restore MQ-9 now): extracted the `veafSpawn-MQ-9 - AFAC - JTAC -
  DRONE` group from `veaf-demo-mission.miz` with `extract-aircraft-groups` (correct
  YAML, categorized under `airplanes`) and added it to the default
  `spawnables.yaml`. Verified the rebuilt mission embeds the template (`-afac` /
  `_cas` AFAC can now resolve it). Aircrafts-injector + defaults tests green (56).
- **Spun off**: the v6 default spawnables also files all 50 CAP **plane** templates
  under the DCS `helicopter` category (`airplanes:` empty) — a stale extraction
  artifact (the current `extract` tool categorizes correctly). Tracked as its own lot
  (FIX-SPAWNABLES-CATEGORY), out of this campaign.
- **Naming gotcha**: the first restore kept the demo's group name `veafSpawn-MQ-9 -
  AFAC - JTAC - DRONE`, but `_cas`/`_spawn afac` search the literal `"mq9"` and
  `findSpawnableAircraftGroupname` matches it as the substring `MQ9` (escapeRegex
  escapes the `-`), which does **not** match `MQ-9`. Renamed the template group
  identifier to `veafSpawn-MQ9 - AFAC - JTAC - DRONE` (the DCS unit type stays
  `MQ-9 Reaper`) so the established `"mq9"` search resolves it.
- **Status**: ✅ fixed (MQ-9 restored + named to match) — David confirmed `_cas`/`-afac` spawn the AFAC in-game.

### R3-FINDING-3 — `_cas` feedback messages are in English 🔍 spun off

- **Remark**: with `_cas` working, David noted its on-screen messages are English
  even though `veaf.config.language = "fr"`.
- **Analysis**: the post-`_cas` confirmation (`veafCasMission.lua:1103`, "TARGET:
  Group of N vehicles…") and the F10 target report (1118-1151) are hardcoded English
  literals, not routed through `veaf.t` — missed by LUA-I18N-004. The detailed report
  (LAT/LON, MGRS, bullseye, weather) is the "data report" category LUA-I18N-004
  explicitly deferred; the short confirmation is straightforward to localize.
- **Decision** (David): handle in a dedicated **LUA-I18N-CAS** lot (not this
  campaign — it's an i18n gap, unrelated to the DCS update). Cosmetic; `_cas` is
  fully functional.

### R7-BUG — `convert-v5` extracts commented-out config as active 🔍 spun off

- **Remark**: `convert-v5` on a real mission (Training-Syrie) produced a `mission.yaml`
  declaring ASSETS (tankers/carriers: `T1-Arco-1`, `CSG-74 Stennis`, …) and QRA groups;
  the subsequent `build` then warned that all 24 of them are "absent from the mission".
- **Analysis**: in the v5 `missionConfig.lua`, the **entire** `veafAssets.Assets`
  block is inside a Lua block comment `--[[ … ]]` (the standard "uncomment to enable"
  template), i.e. ASSETS was **disabled** in v5. But `convert-v5` (1) counted the
  module "active" from the `if veafAssets then` guard alone, ignoring that its whole
  body is commented, and (2) regex-scanned `name=…` definitions **inside** the
  `--[[ ]]` block, emitting 14 phantom assets (and similarly QRA) into `mission.yaml`.
  The mission's real groups are named differently (`Arco11`, `Texaco11`, …), so the
  phantom declarations all fail the build's group-presence check. So the elements
  aren't *missing* — `convert-v5` wrongly *added* disabled config. The `.miz`-format
  read itself was fine (no luadata crash), so R7's actual goal passed.
- **Decision**: dedicated lot **FIX-CONVERT-V5-COMMENTS** (convert-v5 must strip Lua
  `--` line and `--[[ ]]` block comments before detecting active modules and
  extracting ASSETS/QRA). High impact — the VEAF template ships everything commented,
  so most real v5 missions hit this. Unrelated to the DCS update; spun off.
