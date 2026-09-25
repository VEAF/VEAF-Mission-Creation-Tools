# 07 — Zone elements fall back to their declared position, not a random draw

Status: ✅ done
Type: fix

## David's ruling (2026-08-27, rule 3)

"C'est applicable au spawn (`-farp`) mais pas a ce qui est place dans l'editeur de mission (combat
zone, farp statiques, etc.)". Editor content has no user standing there to receive a refusal. A
partial or randomly-relocated zone is worse than a zone that spawns exactly where the mission maker
put it.

## Current behaviour (ticket 02 fixed this partially)

`VeafCombatZone:spawnElement` already falls back to the declared position when `findSpawnPoint`
returns nil -- but `findSpawnPoint` only returns nil after both tier 1 and tier 2 have exhausted. So
when tier 1 finds nothing (38/106 commands on GermanyCW-v6), the element is placed by a **blind
random draw** within its spawn radius, not kept at the declared position.

Observed result: 53 of 184 zone groups had at least one unit in trees or water, even though the
editor anchor was placed on clear ground.

## What this ticket does

Use ticket 06's `noRandomFallback = true` parameter: when tier 1 finds nothing, `findSpawnPoint`
returns nil immediately without running the random tier. `spawnElement` then:

- **Checks the declared position's terrain.** If admissible (`veaf.DEFAULT_SPAWN_TERRAIN` or the
  element's naval surface), it keeps the declared position and logs at trace.
- **If not admissible** (the declared position is in water, or otherwise invalid), it emits a
  **warning** at mission load time and re-runs `findSpawnPoint` with the random tier enabled as a
  last resort -- because a zone element in the sea is worse than one moved a few metres onto dry land.

The arbitration from David, 2026-09-25: **warn + random if declared terrain is invalid (option b)**.

## Definition of done

- [ ] `spawnElement` passes `noRandomFallback = true` to `findSpawnPoint`
- [ ] If nil returned and declared position is on admissible terrain -> keep it (trace log)
- [ ] If nil returned and declared position is NOT on admissible terrain -> warn + run random tier
- [ ] Tests: tier-1-succeeds keeps the found point; tier-1-fails-valid-declared keeps declared;
      tier-1-fails-invalid-declared warns and runs random tier
- [ ] `stylua --check` and `luacheck` clean
