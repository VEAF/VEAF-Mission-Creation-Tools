# 10 — Nested combat zones (difficulty levels) cannot be expressed cleanly

Status: ✅ done (#995)
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

## Outcome (PR 4)

1. **Point 3 was narrower than written.** What deactivation destroys and what completion counts are
   the zone's spawned groups, and since #66 a `#command` group is registered with the zone *running*
   the element (the spawn hook closes over `self`), so a borrowed command already belonged to the
   borrowing zone. The baked `czName` only named the group after its zone of origin — and only when
   `hide_names_from_spawned_groups: false`, since the default hides the zone name anyway. Kept as a
   test (`test_a_borrowed_command_group_belongs_to_the_borrowing_zone`, green before the fix);
   `czName` is now appended at spawn time with the running zone's name.
2. `addZoneElementsFromZoneNamed` skips elements the zone already holds, so borrowing a level that
   has itself borrowed the next one no longer adds them twice. That is what makes the generated
   closure order-independent.
3. `combat_zones[].includes` generated as one `GetZone(z):addZoneElementsFromZoneNamed(i)` per zone
   of the transitive closure, after the last zone is built. Unknown zone, operation, non-list,
   self-inclusion and cycles are build errors.
4. **Two active levels sharing an element: decided, each spawns its own copy**, owned by its zone
   (test `test_two_active_levels_sharing_an_element_each_spawn_their_own`). Levels are played one at
   a time; the doc says so. No exclusion and no reference counting — both would surprise more than
   they help.
5. Doc FR/EN: the `includes` key, the pattern, why prefix nesting is not it.

Left to the GermanyCW-v6 session (the mission is not ours to modify): replace the
`mission-script.lua` block with `includes:` on the medium and hard levels once a build with this
change is available.
