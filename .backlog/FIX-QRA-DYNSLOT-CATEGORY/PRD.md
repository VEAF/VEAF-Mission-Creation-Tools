# FIX-QRA-DYNSLOT-CATEGORY

Status: ✅ done

Fixes [#299](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/299) (reported by Tripack).

## Problem

A dynamic-slot **airplane** does not trigger a QRA unless `react_on_helicopters` is
`true` (or the legacy `:setReactOnHelicopters(...)` line is present at all). With the
default (`false`/absent) the QRA ignores the airplane.

## Root cause (confirmed against the vendored DCS schema)

`veafQraCore.lua:humanBornEvent` reads the intruder category via `unit:getCategory()`
on the dynamic-slot path. Per the DCS API, `Unit:getCategory()` returns an
**`Object.Category`** value — `Object.Category.UNIT == 1` — which **collides** with
`Unit.Category.HELICOPTER == 1`. So **every** dynamic-slot unit (airplane or helicopter)
is classified as a helicopter, and only triggers the QRA when `reactOnHelicopters` is
true. The correct call is `Unit:getCategoryEx()`, which returns a `Unit.Category`
(AIRPLANE = 0 / HELICOPTER = 1).

A second bug compounds it: `VeafQRACore:setReactOnHelicopters()` **ignores its argument**
and always sets `true`, so a legacy `:setReactOnHelicopters(false)` actually enables
helicopter reaction (which is why "any active value works" in the report).

## Fix

1. `humanBornEvent`: use `unit:getCategoryEx()` (Unit.Category) instead of
   `unit:getCategory()` (Object.Category) for the dynamic-slot path.
2. `setReactOnHelicopters(value)`: honor the argument (`nil` → `true` for legacy
   no-arg calls, otherwise the passed value).
3. Mocks: add `Unit:getCategoryEx()` to `test/lua/dcs_mocks.lua` (real in DCS, missing).
4. Lua tests: dynamic-slot airplane triggers with `reactOnHelicopters=false`; helicopter
   only with `true`; `setReactOnHelicopters` respects its argument.

## Out of scope

- The dynamic-slot-templates.yaml extraction categorization (separate lot
  FIX-DYNSLOT-TEMPLATE-CATEGORY — Mission-Editor section, not the QRA runtime path).
- The v6 YAML path is unaffected: `lua_config_generator` only emits
  `:setReactOnHelicopters()` when `react_on_helicopters` is truthy.
