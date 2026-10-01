# 04 — `scenery_targets`: map objects a zone must see destroyed

Status: ✅ done — checked in game 2026-10-01 (after FIX-OBJECTIVE-COMPLETION subscribed the register)

Files: `veaf_libs/lua_config_generator.py`, `src/scripts/veaf/veafCombatZone.lua`,
`src/scripts/veaf/veafMissionDb.lua`, their tests, `doc/mission-maker/scripts/veafCombatZone*.md`.

## Done when

- `combat_zones[].scenery_targets: [<id>, …]` emits one `:addSceneryTarget(<id>)` per id, before
  `:initialize()`. A value that is not a positive integer (a string, a float, `true`, zero, a negative)
  stops the build: it would be a target that can never die.
- `VeafCombatZone:completionCheck` counts each target not yet in the destroyed-scenery register as an
  enemy, whichever side plays the zone. `veaf.isSceneryDestroyed(id)` is the façade.
- The F10 report counts the map objects left; a zone that `includes` another borrows its targets; the
  key on an operation stops the build; a zone with targets is documented as not replayable (the
  register keeps every destruction since the start).
- Tests: generator (setters emitted, bad values refused, refused on an operation); Lua (a standing
  target keeps the zone active, a destroyed one completes it, every target is needed, a non-id is
  ignored, an id is kept once, `includes` borrows, the report counts); the façade answers by id.

## To check in DCS

A zone holding only `scenery_targets: [<id of a bridge>]`, active at start: destroy the bridge, the zone
announces its completion within one watchdog period.
