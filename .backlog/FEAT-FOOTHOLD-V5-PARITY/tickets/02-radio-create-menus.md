# 02 — RADIO: expose `create_menus`

Status: ✅ done
Type: feat

## Why

See the [PRD](../PRD.md), gap 2. `veafRadio.initialize` takes
`(skipHelpMenus, dontCreateMenus)`, but the RADIO module exposed only `help_menus`, so a mission
could not suppress the VEAF F10 menu. The v5 Foothold called `initialize(true, true)`: no menu,
commands reachable only through password-protected map markers.

## Design

`init.create_menus: false` → `dontCreateMenus = true`. The YAML says what the mission-maker
wants; the negation happens on the way out, because the Lua parameter is phrased negatively.

The key is **optional**, not defaulted: `_MODULE_INIT_PARAMS` entries whose default is `None`
are omitted from the call unless declared. A mission that never mentions `create_menus`
therefore generates the exact same `veafRadio.initialize(true)` as before — adding the key
changes nothing for anyone else.

## Tasks

- [x] `create_menus` in `_MODULE_INIT_PARAMS`, with the optional-when-`None` mechanism.
- [x] `_NEGATED_INIT_KEYS` for the YAML→Lua negation.
- [x] Tests: `false` → `initialize(true, true)`; `true` → `initialize(true, false)`; omitted →
      `initialize(true)` unchanged (regression guard).
- [x] Document the RADIO `init:` fields in `MISSION_YAML_REFERENCE` (FR + EN), including why
      hiding the menu goes with `security:`.
- [x] mypy: renamed the loop variable — reusing `yaml_key` clashed with a later loop in the same
      scope that assigns `None` to it, which mypy caught.
