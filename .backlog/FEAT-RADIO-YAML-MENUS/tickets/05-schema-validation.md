# 05 — Schema validation for the new YAML keys

Status: ✅ done

## Context

The new surfaces (`modules.RADIO.user_menus`, QRA/AirWave `radio_menu`) need
validation in `mission_validator.py` so mistakes are caught with a clear message at
build/validate time rather than producing broken Lua.

## Tasks

- [ ] Validate `RADIO.user_menus`: `restrict_to_group` (string), `tree` (list),
      each node either a `menu` (name + `items`) or a leaf `command` with an
      `action`.
- [ ] Validate the **closed action vocabulary** and each action's required target:
      `qra.*`→`qra`, `airwave.*`→`airwave`, `flag.set`→`flag`+`value`,
      `flag.on/off/increment/decrement`→`flag`, `message`→`text`,
      `lua`→`function`. Unknown action or missing target → error naming the item.
- [ ] Validate the per-module shortcut keys (`radio_menu` boolean,
      `radio_menu_restrict_to_group` string) on QRA definitions and AirWave zones.
- [ ] Messages routed through `t()` (FR/EN), consistent with existing validator
      errors.

## Definition of Done

- Invalid vocabulary / missing target / malformed tree each raise a clear,
  localized validation error; valid blocks pass.
- Unit tests cover each error path and a valid tree.
- Quality ratchet: if `mission_validator.py` is substantially edited and still in the
  mypy `ignore_errors` list, drop it and fix the errors. Coverage gate bumped.
