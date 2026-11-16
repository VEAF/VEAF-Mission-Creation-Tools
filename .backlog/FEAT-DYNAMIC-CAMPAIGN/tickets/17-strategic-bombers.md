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

## Checked in game

2026-11-16, test mission `Dynamic Test`, red starting with 1500 points: the red raid left Senaki for Ozurgeti at about 15 min, and the intercept task was posted. Still to see: the drop, and the escort following its bomber.

The red stock of 300 the test campaign first had could never pay the first raid (CAP, helicopter and the strike leaving at the same beat leave ~200, the raid needs 160 above the reserve of 100): with the default values, a side affords raids only with factories standing — a point for the server tuning (ticket 10).

## Combined raid (David, 2026-11-16, after the first raid in game)

The first raid in game flew into the blue SAM umbrella over Ozurgeti: the Tu-22M3, locked, turned away south-east and jettisoned its bombs, which never armed, and was shot down on its way home; two red MiG-29 of the CAP were shot down by the same SAMs.

- A raid is now a package: a BARCAP on the axis out of the target's air defence reach (`barcapStation`), a SEAD flight ahead at the zone whose air defence covers the target, and the bomber `bombers.package_delay` (180 s) later.
- No escort by default (David: the BARCAP holds the approach, the last leg is the players' interception window); `bombers.escort: true` brings it back.
- The bomber does not react to threats (`REACTION_ON_THREAT` = `NO_REACTION`) nor jettison (`PROHIBIT_JETT`).
- Paid whole or not at all; the shop's raid is the same package, 1300 credits (220 points at 6 credits a point).
- The enemy's CAP circle stops `BARCAP_MARGIN` short of the players' air defence reach, `CAP_MIN_RADIUS` (5 km) at least.
