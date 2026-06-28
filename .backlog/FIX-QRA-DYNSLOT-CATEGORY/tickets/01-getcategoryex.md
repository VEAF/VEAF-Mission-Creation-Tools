# 01 — QRA dynamic-slot category via getCategoryEx + honor setReactOnHelicopters arg

Status: ✅ done

## Tasks

- [x] `veafQraCore.lua:humanBornEvent`: use `unit:getCategoryEx()` (Unit.Category) on the
      dynamic-slot path instead of `unit:getCategory()` (Object.Category, collides with
      HELICOPTER==1).
- [x] `setReactOnHelicopters(value)`: honor the argument (`nil` → `true`, else value).
- [x] `test/lua/dcs_mocks.lua`: add `Unit:getCategoryEx()` (configurable for tests).
- [x] Lua tests: airplane dynamic-slot triggers with `reactOnHelicopters=false`;
      helicopter dynamic-slot triggers only with `true`; `setReactOnHelicopters` arg honored.
- [x] `stylua --check` (clean) + `luacheck` (CI gate) + `poetry run test-lua` (green); CHANGELOG; PATCH bump 6.7.6 → 6.7.7.

## Definition of Done

- A dynamic-slot airplane triggers the QRA regardless of `react_on_helicopters`.
- Lua suite green; lua-coverage ratchet held; stylua/luacheck clean (CI).
