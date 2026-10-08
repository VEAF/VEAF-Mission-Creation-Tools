# FEAT-CONVOY-UNDER-FIRE — a convoy that watches ahead, splits, calls for help and falls back

Status: 🔄 in-progress

David, 2026-10-08, while writing up [`FEAT-LIVE-GAME-MASTER`](../FEAT-LIVE-GAME-MASTER/PRD.md): "ça serait vraiment bien si tu pouvais suppléer à l'IA de DCS qui est nulle, surtout pour le comportement des unités au sol".
His example — "juste un exemple" — is a friendly convoy that meets opposition: DCS just stops it while the enemy destroys it at leisure.
It should take defensive measures, call for CAS, and fall back to the safest place, keeping obstacles between the enemy and itself.

## Why in the mission and not through Claude

A convoy under fire has a minute or two.
Claude acts when someone writes to it, with seconds of latency per turn; reacting in time would mean watching the mission continuously, an autonomous loop `FEAT-LIVE-GAME-MASTER` leaves out, paid in tokens for the whole flight.
So the reflexes live in the mission, in Lua, and work with nobody in the conversation — in any mission, game master or not.
The game master can still steer them: "replie le convoi" is a command like any other (ticket 05).

## What exists — read 2026-10-08

- `veafGroundAI` ("Slightly Less Dumb Ground AI") has the frame: a `GroundUnitHandler` per group, a scheduled `check()`, orders, marker commands (`_gc <name>, <verb> <value>`).
  Only the artillery handler is implemented; nothing reacts to contact.
- `_spawn convoy` (`veafSpawnGround`) spawns the convoys this lot is first for, keeps them in `veafSpawn.spawnedConvoys` and walks their itinerary with `convoyArrivalWatchdog`, which respects the record's `stopped` flag.
- Where "blue-held" is known: the campaign zones and their owner (`veafCampaign.zoneList`), airbases' coalition.
- Line of sight: `land.isVisible(p1, p2)` answers whether terrain masks one point from another.
- Towns: `veafCities` holds their positions, by theatre, in latitude and longitude.
- A voice from the mission: `veafRadio._transmitViaSRS`, mute today on DAVID-BUREAU and dcs.veaf.org for lack of `SERVER_CONFIG.SRS_*` (and of `os` on the server).

## Measured in DCS, 2026-10-08 (ticket 01)

On Caucasus, east of Kutaisi, through the fiddle hook: a blue convoy driven along a road into three red vehicles (two BMP-2, a BTR-80) placed 400 m off it.

| # | Question | Measured |
|---|---|---|
| 1 | Events when shot at and hit | The ambush opened fire at ~1.3 km. `S_EVENT_SHOOTING_START` arrives **with its target** (a convoy unit) and its shooter; `S_EVENT_HIT` too, though some hits by shells carry a nameless initiator; a Konkurs `S_EVENT_SHOT` carries no target. A truck's explosion raises `S_EVENT_HIT` on its neighbours with the truck as initiator — it looks like friendly fire and is not. |
| 2 | `getDetectedTargets` for a ground group | A convoy of HMMWV, Stryker and trucks: **empty for 45 s under fire**, until a single vehicle was left. The same convoy with a Bradley: an enemy detected at 1 227 m, 10 s before the first shot. Not a trigger to rely on. |
| — | DCS's own reaction | None: the first convoy drove on at 10 m/s without firing a round until all four vehicles were dead. |
| 3 | Smoke against an AI shooter | Three `effectSmokeBig` (preset 7) between the BMPs and their target: they kept detecting all three targets and firing (≈300 hits in 60 s). **Smoke does not blind DCS's AI**; it is for the players' eyes. |
| 4 | Options and a new route while engaged | Alarm red, ROE open fire and a new `Mission` task applied at the first shot: the **lead** turned and drove back within 3 s, the convoy returned fire and killed two of the three. But **only the lead obeyed**: the column stalled off road, a truck stayed on the road and was destroyed, another was damaged. A ground group moves as one; there is no per-vehicle order. |
| 5 | `world.searchObjects` and trees | 117 scenery objects within 3 km — buildings, bridges, light poles — **no tree**. Forest cannot be found as cover; terrain and towns only. |
| 6 | Cost of `land.isVisible` | 2 000 calls in 28 ms, ~14 µs each. Line-of-sight work is not the limit. |
| 7 | Smoke marker duration | Still there after 3 min (David, by eye); the end not timed — the scripting API cannot read it. Renewed every 5 min meanwhile. |

Also seen: stationary trucks 1 km from the BMPs, in line of sight by `isVisible`, were **never detected** in five minutes; at 350 m they were engaged at once. Whatever masks them (vegetation, most likely) is not something `isVisible` sees.

## Design — decided 2026-10-08

David's proposal, after the first two runs: react **before** the first shot, by looking.

1. **Wide watch, every 30 s** — `world.searchObjects` around the convoy, radius 5 km + 60 s of driving at its speed; living enemy ground units only (`searchObjects` returns destroyed ones too — see the known limitations). The radius already covers well over the 30 s to the next watch, so the route ahead is not searched separately.
2. **Close watch, every 3 s** — while an enemy is within that radius: line of sight (`land.isVisible`, eyes at 2.5 m) from every convoy vehicle to every enemy.
3. **Contact** — an enemy in sight within 3 km, **or** a shot or hit received (the net that catches artillery and aircraft).
4. **Split** — the unarmed vehicles are respawned as their own group, where they stand, and flee at once; the armed ones stay in the original group, which keeps its name (`_gc`, the convoy registry). A wholly unarmed convoy flees as one. DCS cannot set a respawned unit's damage: a damaged truck comes back whole; with the early watch the split almost always comes before the first hit (decision 2).
5. **Fight or fall back** — the armed group's strength (DCS attributes: tank 4, IFV 3, APC, AAA or armed ground unit 1, unarmed 0 — read in DCS on 2026-10-08) against the enemies in sight: at least 1.5 times theirs, it **closes in** to 900 m of the nearest one, alarm red, weapons free; otherwise it falls back too, after the unarmed group. An aircraft, or a shooter beyond 3 km, counts as unanswerable: fall back.
   Not a halt, as first written: in game, two Bradleys halted 1.9 km from the enemy the watch saw fired nothing for two minutes — neither `Controller.knowTarget` nor `FireAtPoint` changed it — and sent forward they destroyed both enemies in 16 s, from ~1.3 km.
6. **Call for help** — to the convoy's coalition, in the shape of a troops-in-contact call; red smoke near the enemy, green on the convoy, **only with the call** (David: no smoke screen, since it blinds nobody).
7. **Fall back** — to the nearest friendly place (a campaign zone the side owns, a friendly airbase), preferably by road (off road, the second run's column bogged down at 0.6 m/s), on a route masked from the enemy by terrain or a town where one exists.
8. **Afterwards** — nothing in sight for 60 s: the armed group reports and holds; the unarmed group waits where it fell back. On `resume`, the unarmed group drives straight across to the armed one (sent "On Road", it drove away to reach the road network first) and the two are merged back into one group once within 300 m — `coalition.addGroup` under the convoy's own name replaces it (measured).

The troops-in-contact wording follows JP 3-09.3 (25 November 2014): "troops in contact" is friendly forces receiving effective fire, an advisory call that highlights urgency (p. III-36); an immediate request names the unit called and the caller, priority #1 emergency, and "target is / number of" (Appendix A, Section I).

Found by the in-game run: a server whose `SERVER_CONFIG` lacks the `SRS_*` keys left `STTS.DIRECTORY` nil, and `veafRadio._transmitViaSRS` raised on it — inside the convoy's watch, which died. Fixed at the root in `veafRadio`, and the convoy guards its voice and its beat anyway.

## Questions — decided 2026-10-08

| # | Question | Decision |
|---|---|---|
| Q1 | Which groups behave like this | every convoy spawned by `_spawn convoy`, plus any group a mission maker hands to `veafGroundAI` as a convoy |
| Q2 | Red convoys too | yes, the same code with the sides swapped; the call for help then goes to red |
| Q3 | The voice from the mission | `SERVER_CONFIG.SRS_*` in DAVID-BUREAU's `Saved Games\DCS\DCS-SimpleRadio-Standalone\SRS_for_scripting_config.lua` — the file `veafRadio` reads, as on dcs.veaf.org's Foothold instance; the block is in the ground AI page, prepared for David; **not on dcs.veaf.org's other instances for now** — the text goes alone there |
| Q4 | After the contact | hold, report, and wait for an order (a human or Claude), rather than drive back into the same ambush |

## Out of scope

- Other ground behaviours (an assault, a SAM site relocating, infantry dismounting): this lot builds the convoy handler and the watch they would reuse.
- An autonomous Claude watching the fight.

## Tickets

- [01 — measure what DCS gives and honours](tickets/01-measure-dcs.md)
- [02 — the watch, the split and the fight](tickets/02-contact-and-defence.md)
- [03 — the call for help](tickets/03-call-for-help.md)
- [04 — falling back behind cover](tickets/04-fall-back-behind-cover.md)
- [05 — orders from a human or the game master](tickets/05-orders.md)
- [06 — documentation, demo step, known limitations](tickets/06-docs-demo-limitations.md)
- [07 — the in-game check](tickets/07-in-game-check.md)
