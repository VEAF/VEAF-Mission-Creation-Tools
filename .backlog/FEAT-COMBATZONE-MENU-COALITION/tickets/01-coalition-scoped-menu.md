# 01 — Show a combat zone's F10 menu to its own side only

Status: ✅ done

## Goal

Stop each coalition from seeing — and being able to activate — the other side's combat zones.

## Definition of Done

- [x] `veafRadio.addSubMenu(title, parent, coalitionSide)` renders through DCS's `ForCoalition`
      menu API, with the side inherited by child submenus, commands and pagination pages
- [x] a `USAGE_ForGroup` command in a scoped subtree only reaches that coalition's groups;
      `veafRadio.humanGroups` records each group's coalition
- [x] `rebuild()` removes scoped nodes explicitly (no duplicate menu per player join)
- [x] a zone defaults to `getFriendlyCoalition()`; `radio_menu_coalition: RED | BLUE | ALL`
      overrides it
- [x] `lua_config_generator` emits `:setRadioMenuCoalition(...)`, rejects an unknown value,
      emits nothing when absent
- [x] Lua tests (scoped vs global API, inheritance, per-group filtering, unknown-side group kept,
      pagination, rebuild removal) + zone-level tests + Python tests
- [x] DCS mocks gain the `ForCoalition` entries and the missing `veafRadio` stubs
- [x] FR + EN doc sections, including the behaviour-change notice
- [x] `mission.yaml` defaults, authoring skill, `CHANGELOG.md`, version 6.11.8
- [x] Lua coverage floor raised 67 → 69 (measured 70.93%)

## Left to verify in game

Whether DCS accepts a coalition-scoped submenu under a global parent (the VEAF root and
`COMBAT ZONES` stay global). Not provable from the sources or the mocks — see the PRD.
