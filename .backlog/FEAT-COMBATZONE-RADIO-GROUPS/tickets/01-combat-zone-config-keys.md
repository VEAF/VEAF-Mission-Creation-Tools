# 01 — Combat-zone `radio_group_name` + `radio_menu_prefix` config keys

Status: ✅ done

## Context

`veafCombatZone` already exposes `setRadioGroupName` (groups zones under a named
intermediate submenu, consumed by `buildRadioMenu`) and `setRadioMenuPrefix`
(prefixes the zone's menu label), but no config path feeds them:
`lua_config_generator.py._emit_combat_zone_def` emits `friendly_name`, `briefing`,
`training`, chained zones… but not these two. Add both as optional per-zone keys.

## Tasks

- [x] In `_emit_combat_zone_def` (`lua_config_generator.py`), emit
      `:setRadioGroupName("<v>")` when `zone_def["radio_group_name"]` is present, and
      `:setRadioMenuPrefix("<v>")` when `zone_def["radio_menu_prefix"]` is present,
      placed in the builder chain like the other string setters.
- [x] Do NOT add them to combat *operations* (`_emit_combat_operation`) — scope is
      combat zones only.

## Decision — no ad-hoc schema validation

The planned per-key type validation was **dropped**: combat-zone attributes have
**no** type/unknown-key validation anywhere today (`collect_module_issues` stops at
the module level; `friendly_name`, `briefing`, … are consumed by `.get()` and
unknown keys are silently ignored). Adding a bespoke check for these two keys only
would be an inconsistent new pattern (RULE simplicity/surgical) with little value —
they are optional strings emitted verbatim. Validation stays out of scope.

## Definition of Done

- Given a combat zone with `radio_group_name` / `radio_menu_prefix`, the generated
  config Lua contains the matching `:setRadioGroupName(...)` / `:setRadioMenuPrefix(...)`
  call; absent keys emit nothing. Unit test covers present + count.
- `ruff`, `ruff format --check`, `mypy`, `pytest` green.
