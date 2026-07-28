# 01 — `enemy_coalition` on a combat zone

Status: ✅ done

## Goal

Let a combat zone be played from the red side by making the enemy coalition a setting instead of
a hard-coded RED.

## Definition of Done

- [x] `VeafCombatZone.enemyCoalition` (default red) + `setEnemyCoalition` / `getEnemyCoalition` /
      `getFriendlyCoalition`, accepting a side number or a `"red"`/`"blue"` string
- [x] the watchdog completes on the **enemy** count, not the red count
- [x] the F10 report labels friends/enemies from the setting
- [x] `lua_config_generator` emits `:setEnemyCoalition(...)` for `enemy_coalition: BLUE`, nothing
      for RED/omitted, and rejects an unknown value
- [x] Lua tests (default, blue-sided completion, report labels, setter forms) + Python tests
- [x] `doc/mission-maker/scripts/veafCombatZone.md` + `.en.md` document the field and drop the
      "required for a zone with no RED unit" framing of `completable`
- [x] `src/defaults/mission-folder/mission.yaml` mentions the key (defaults lockstep)
- [x] `CHANGELOG.md` entry, PATCH version bumped in `pyproject.toml` + `plugin.json`
