# 01 — Combat-zone `radio_group_name` + `radio_menu_prefix` config keys

Status: ⬜ ready

## Context

`veafCombatZone` already exposes `setRadioGroupName` (groups zones under a named
intermediate submenu, consumed by `buildRadioMenu`) and `setRadioMenuPrefix`
(prefixes the zone's menu label), but no config path feeds them:
`lua_config_generator.py._emit_combat_zone_def` emits `friendly_name`, `briefing`,
`training`, chained zones… but not these two. Add both as optional per-zone keys.

## Tasks

- [ ] In `_emit_combat_zone_def` (`lua_config_generator.py`), emit
      `:setRadioGroupName("<v>")` when `zone_def["radio_group_name"]` is present, and
      `:setRadioMenuPrefix("<v>")` when `zone_def["radio_menu_prefix"]` is present,
      placed in the builder chain like the other string setters.
- [ ] Validate the two keys in `mission_validator.py` (optional strings on a
      combat-zone entry; clear error on wrong type).
- [ ] Do NOT add them to combat *operations* (`_emit_combat_operation`) — scope is
      combat zones only.

## Definition of Done

- Given a combat zone with `radio_group_name` / `radio_menu_prefix`, the generated
  config Lua contains the matching `:setRadioGroupName(...)` / `:setRadioMenuPrefix(...)`
  call; absent keys emit nothing. Unit tests cover present / absent / both.
- Validator accepts valid values and rejects non-string ones with a clear message;
  test added.
- `ruff`, `ruff format --check`, `mypy`, `pytest` green; coverage gate bumped.
