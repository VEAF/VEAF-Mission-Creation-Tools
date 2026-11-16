# 17 — Strategic bombers: an escorted red raid, a blue raid bought

Status: 🧑 waiting-human — built and tested outside DCS in #1282 (2026-11-16); the in-game check of the test mission is David's

PRD row "Strategic bombers"; analysis note 03 §12.

## What

- **Red raid**: every `bombers.seconds` (3600 s), the enemy side sends a bomber flight with an escort, paid from its resources (ticket 12), at the players' zone with the most to hit — a factory first, else the zone with the most garrison units. It starts in the air over the enemy airfield zone nearest the target that is at least `bombers.min_distance` (80 km) from it, so that the players have time to intercept without the raid crossing the whole map; the escort is the side's CAP aircraft, following the bomber.
- The players hear of it at once ("bombers inbound to …") and the task board posts an **intercept** task (`tasks.rewards.intercept`, 400) done when the bombers are shot down, withdrawn when the raid ends.
- **Blue raid**: a shop item, `bomber` (1200 credits), on an enemy zone: the players' bomber flight, with an escort, from their airfield zone chosen the same way; it bombs the zone's buildings and garrison and goes home.
- The bombers are declared like the other aircraft: `dynamic.air.<side>.bomber`, type and loadout; defaults Tu-22M3 `FAB-250*33` (red) and B-1B `Mk-82*84` (blue), one aircraft each — loadouts read from the shipped DCS ones.

## Done when

Lua tests: the raid's target, origin and timing; nothing sent when the side cannot pay or has no airfield far enough; the intercept task posted and closed; the shop item.
In game: the bomber flies to the target and drops; the escort follows it.
