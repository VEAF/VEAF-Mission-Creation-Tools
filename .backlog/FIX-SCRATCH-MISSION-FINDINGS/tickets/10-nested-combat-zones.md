# 10 — Nested combat zones (difficulty levels) cannot be expressed cleanly

Status: ⬜ ready
Type: fix + feat
Files: `src/scripts/veaf/veafCombatZone.lua`, `veaf_libs/lua_config_generator.py`, `doc/mission-maker/scripts/veafCombatZone.md`, tests

## The need

A training range in progressive levels on the same targets — easy (inert), medium (light AAA),
hard (realistic SHORAD) — where activating a level also spawns everything of the levels below.
David asked for exactly that on GermanyCW-v6 (Baumholder, next to Ramstein, like Kobuleti on Caucasus).

## What stands in the way today

1. **Not expressible in `mission.yaml`.** The only mechanism is the Lua builder
   `VeafCombatZone:addZoneElementsFromZoneNamed(otherZone)`; GermanyCW-v6 calls it from
   `mission-script.lua`, after `veaf-config.lua` has created the zones.
2. **Nesting by overlapping name prefixes cannot work**, although the prefix rule suggests it
   (`zone_Hard`, `zone_Hard_Medium`, `zone_Hard_Medium_Easy`, a group named after the deepest one
   matching all three): at `initialize()` a zone **destroys** the groups it captured
   (`veafCombatZone.lua` ~l. 1404-1420), and `findUnitsInCombatZone` looks at **live** units, so the
   second zone to initialize finds nothing.
3. **A borrowed `#command` element stays bound to its zone of origin**: `buildCommandElement` bakes
   `", czName " .. combatZoneName` into the command (~l. 544). Borrowed by another level, its spawn
   still belongs to the original zone — not cleaned when the borrowing zone deactivates, not counted
   for its completion. GermanyCW-v6 had to use native groups only in its lower levels.

## What ships

- `combat_zones[].includes: [<zone_name>, ...]` in `mission.yaml`, generated as
  `addZoneElementsFromZoneNamed` after all zones exist (order-independent, transitive, cycle-checked)
- a borrowed `#command` element spawns for the **borrowing** zone (resolve `czName` at spawn time
  rather than at element construction)
- doc: the pattern, and why prefix nesting is not it

## Done when

- Tests: a level including another spawns both sets; its deactivation removes both; its completion
  counts both; a `#command` element in a lower level works
- GermanyCW-v6's `mission-script.lua` nesting replaced by `includes:`, the lower levels free to use
  `#command` again
