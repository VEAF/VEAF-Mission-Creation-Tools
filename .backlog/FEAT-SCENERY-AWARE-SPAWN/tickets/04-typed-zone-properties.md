# 04 — Typed trigger-zone property accessors

Status: ✅ done
Type: feat
Files: `src/scripts/veaf/veaf.lua`, `test/lua/test_veaf.lua`

Depends on: nothing. Ships even if ticket 01 comes back negative.

## Problem

`veaf._discoverTriggerZones` copies the DCS `properties` table into every cached zone
(`veaf.lua:4375`) and **no code in the repo ever reads it**. A mission maker can therefore type
properties onto a trigger zone in the Mission Editor and VEAF has no way to consult them — the data
crosses the boundary and dies in the cache.

DCS hands them over as an array of pairs, not a map, and every value is a **string**:

```lua
properties = { [1] = { key = "smoke", value = "true" }, [2] = { key = "radius", value = "800" } }
```

So each caller would otherwise write its own linear scan plus its own `tonumber` / `"true"`
comparison. TUM factored exactly this into typed readers (`DCSEx.zones.getPropertyBoolean/Float/Int/Parse`,
`TheUniversalMission.lua:3257-3271`) — the shape worth borrowing, re-derived rather than copied.

## Behaviour

Built on the existing `veaf.getTriggerZone(zoneName)`, taking the zone **name** so a caller needs no
knowledge of the cache layout:

```lua
veaf.getZoneProperty(zoneName, key)                          --> string | nil
veaf.getZonePropertyBoolean(zoneName, key, default)          --> boolean
veaf.getZonePropertyNumber(zoneName, key, default, min, max)  --> number   (clamped)
```

- Missing zone, missing `properties`, missing key, or unparseable value → `default` (and `nil` for
  the raw reader). Never an error: a mission maker's typo must not kill a module at init.
- Booleans accept `true`/`false` case-insensitively; anything else is a miss, not a `false`.
- `min`/`max` are optional and **clamp** rather than reject, matching TUM's semantics — a mission
  maker who types `radius = 99999999` gets the maximum, not a dead module.
- One accessor for numbers, not the `Float`/`Int` pair: Lua 5.1 has a single number type, so the
  split would be decoration. RULE N°2.
- `getPropertyParse` (string → enum mapping) is **not** ported. No caller needs it, and adding it
  now would be speculative.

No consumer is wired in this ticket — the accessors are the deliverable. The first real user will
come from a lot that needs per-zone configuration, and *that* lot picks the keys.

## Tasks

- [x] Three accessors in `veaf.lua`, next to `veaf.getTriggerZone`.
- [x] Tests in `test_veaf.lua` against a mocked `env.mission.triggers`: hit; missing key; missing
      zone; zone with no `properties` at all; non-numeric value where a number is asked; clamping at
      both bounds; boolean case variations (`TRUE`, `False`) and a junk value falling back to default.

## Acceptance criteria

- [x] `poetry run test-lua`: 14 new tests, no regression. Coverage floor not bumped — see ticket 03's
      acceptance criteria for the measured figures and the reason.
- [x] `luacheck` + `stylua --check` clean.
- [x] Documented in `doc/LUA_API_REFERENCE.md` (FR + EN) — see ticket 05.
