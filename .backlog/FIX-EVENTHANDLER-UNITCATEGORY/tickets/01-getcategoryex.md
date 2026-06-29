# FIX-EVENTHANDLER-UNITCATEGORY-001 — populate event unitCategory via getCategoryEx

Status: 🔄 in-progress
Type: fix
Files: `src/scripts/veaf/veafEventHandler.lua`, `test/lua/test_veafEventHandler.lua`

## What to build

`veafEventHandler.completeUnitFromName` must set `unitCategory` from `unit:getCategoryEx()`
(a `Unit.Category`: AIRPLANE=0 / HELICOPTER=1 / …) rather than `unit:getCategory()` (an
`Object.Category` whose UNIT=1 collides with HELICOPTER), falling back to `getCategory()`
only when `getCategoryEx` is unavailable.

## Acceptance criteria

- [ ] `completeUnitFromName` returns `unitCategory == Unit.Category.AIRPLANE` for an airplane
- [ ] A dynamic-slot airplane triggers the QRA with `react_on_helicopters` false (the #299 symptom)
- [ ] Regression test added; Lua suite + luacheck/stylua green
