# QRA vs AirWaves — the comparison

Written 2026-10-05 from a full read of `veafQraCore.lua`, `veafQraLogistics.lua`, `veafQraManager.lua` and `veafAirWaves.lua`, and a sweep of the mission repositories next to VMCT.

## Verdict {#verdict}

**No-go on merging the behaviours, go on merging the plumbing** (David, 2026-10-05: option b, one PR).

A QRA is not a single-wave AirWave with a re-arm rule: the two modules look at the scene from opposite sides, and their life cycles have different shapes.
What they share is the code underneath — zone geometry, drawing, altitude filter, group choice, spawning — and that is where the duplication, and the bugs it breeds, actually sit.

## What differs {#differs}

| | QRA | AirWaves |
|---|---|---|
| Point of view | The AI **defends** its ground against enemy humans | Humans **enter a challenge**; the waves are the opponent |
| Life cycle | An endless loop: ready → deployed → dead → re-armed → ready | A game with an end: wave 1, 2… → won (`OVER`, terminal), or lost when the players die → reset |
| What spawns | Chosen by the **number of enemies** in the zone | A **sequence of waves**, regardless of how many players |
| "Lost" means | My QRA is dead | The players are dead |
| Messages go to | The enemy coalitions | The players in the zone (with BRA) |
| Only here | Airbase link (used: ~140 `airport_link` lines in the v6 missions), logistics, helicopters, STOP/OUT/NOAIRBASE states | AI leash (destroyed out of zone), flak on a player leaving the zone, crippled-unit despawn, replaceable death callbacks |

Merging them into one engine would mean one state machine carrying two opposite logics, behind `if mode == qra` branches, with every live QRA (55 `VeafQRA:new` files outside VMCT) as the regression surface.

## What is duplicated {#duplicated}

- zone geometry: trigger zone, or centre + radius, or coordinates
- drawing the zone on the map
- altitude floor and ceiling
- message and callback setters, `silent`
- random group choice with bias
- the whole spawn branch, `[lat,lon]` command or editor group (`VeafQRACore:deploy`, `AirWaveZone:deployWaves`, ~110 lines each)

What the duplication has cost, measured:

- FIX-WAVE-OFFSET-AXES had to fix the same axis swap in four places across both modules.
- VMR-085 (missing trigger zone) was fixed in AirWaves only: `veafQraCore.lua:966-969` still reads `triggerZone.x` without a `nil` test. Latent today — a YAML QRA never sets a centre next to its zone — but it is the same bug, still there.

## Found on the way {#found}

- **QRA logistics is not exposed in `mission.yaml`.** Outside VMCT it only appears in the commented template of a `missionConfig.lua` (Falklands, for one). The lot leaves it untouched.
- **`AirWaveZone` passes `self.coalition` to `veafInterpreter.execute`, and no setter ever fills it.** Command-declared waves spawn with a `nil` coalition. To be confirmed and fixed in the shared spawn.

## What the six issues need {#issues}

The PRD read the five capabilities as "what QRA needs from the host". Only two touch the shared base:

- #186 mobile zone (a carrier)
- #183 link a zone to entities — the generalisation of the QRA's `airport_link`

The other three are AirWaves gameplay alone: #182 friendly waves, #179 no return once dead, #176 unimportant groups.
#185 (replace the QRA module) is answered by the verdict above.
