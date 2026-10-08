# FEAT-CONVOY-UNDER-FIRE — a friendly convoy that defends itself, calls for help and falls back

Status: ⬜ ready

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
- `_spawn convoy` (`veafSpawnGround`) spawns the convoys this lot is first for.
- Where "blue-held" is known: the campaign zones and their owner (`veafCampaign.zoneList`), airbases' coalition, combat zones.
- Line of sight: `land.isVisible(p1, p2)` answers whether terrain masks one point from another — the actual measure of "an obstacle between the enemy and us".
- Towns: `veafCities` holds their positions.
- Smoke markers: `trigger.action.smoke`; a big smoke effect: `trigger.action.effectSmokeBig`.
- A voice from the mission: `veafRadio._transmitViaSRS`, mute today on DAVID-BUREAU and dcs.veaf.org for lack of `SERVER_CONFIG.SRS_*` (and of `os` on the server) — measured in `FEAT-LIVE-GAME-MASTER`'s PRD.

## What the convoy does

1. **Contact** — it knows it is engaged: a unit hit, a shot fired at it, an enemy its units detect within weapons range.
2. **Defensive measures** — alarm state red, weapons free, a formation that puts its armed units in front of the threat, and a smoke screen between the threat and itself if DCS's AI is blinded by smoke (ticket 01 measures it first; otherwise the smoke is for the players' eyes only, and said so).
3. **Call for help** — to its coalition: text, and voice on guard when the mission can speak, in the shape of a troops-in-contact call (format to be sourced, not invented); red smoke near the enemy, green on itself, so a CAS pilot sees both.
4. **Fall back** — to the nearest blue-held place, along a route chosen so that terrain (`land.isVisible`) or a town stands between the enemy and the convoy; when no masked route exists, the shortest way out of the enemy's range.
5. **Afterwards** — once out of contact for a while, it reports and holds (Q4).

## Questions for when the lot is taken

| # | Question | Recommendation |
|---|---|---|
| Q1 | Which groups behave like this | every convoy spawned by `_spawn convoy`, plus any group a mission maker hands to `veafGroundAI` with a `convoy` handler (`mission.yaml` or `_gc`) |
| Q2 | Red convoys too | yes, the same code with the sides swapped, so the players' targets stop being sitting ducks; the call for help then goes to red, which nobody hears |
| Q3 | The voice from the mission | `SERVER_CONFIG.SRS_*` added to DAVID-BUREAU's `MissionScripting.lua` (three lines, prepared for David; accepted 2026-10-08); on dcs.veaf.org, handing `os` to the missions of a public server is David's decision when the lot is taken, and the text goes alone until then |
| Q4 | After the contact | hold, report, and wait for an order (a human or Claude), rather than drive back into the same ambush |

## Out of scope

- Other ground behaviours (an assault, a SAM site relocating, infantry dismounting): this lot builds the convoy handler and the contact detection they would reuse.
- An autonomous Claude watching the fight.

## Tickets

- [01 — measure what DCS gives and honours](tickets/01-measure-dcs.md)
- [02 — contact and defensive measures](tickets/02-contact-and-defence.md)
- [03 — the call for help](tickets/03-call-for-help.md)
- [04 — falling back behind cover](tickets/04-fall-back-behind-cover.md)
- [05 — orders from a human or the game master](tickets/05-orders.md)
- [06 — documentation, demo step, known limitations](tickets/06-docs-demo-limitations.md)
- [07 — the in-game check](tickets/07-in-game-check.md)
