# FIX-GROUNDAI-CLOSE-IN-REACHABLE — a convoy closes in on a point it can reach, and checks that it moves

Status: ✅ done — merged in #1328 and #1331 (2026-11-22), on `develop` with #1336 (2026-11-23), shipped in 6.39.0

Flight check: on the Campagne server, convoys close in on a reachable point, a push that moves nothing is replaced within 25 s, and a spawned convoy leaves within seconds (tickets 01 to 03's in-game checks).

The cause behind FIX-CAMPAIGN-CONVOY-STUCK-IN-CONTACT, which treats the consequence (a push that moves nothing is not a contact). David, 2026-11-22: create the lot, from a note of the dcs-cartographie session.

## Measured and read

On the Campagne server, 2026-11-21: the convoy [Aleppo - Menagh assault] ("Mule") was pushed by `ConvoyUnitHandler:closeIn` every two minutes from 22:00 UTC onto an enemy "956 m away", then "957 m": it never moved.

`closeIn` (`veafGroundAI.lua` around line 2020) gives the convoy a two-point `Off Road` route, from its average position to the nearest enemy's exact point: one segment of about a kilometre.

The dcs-cartographie session (`D:\dev\_dcs-other\dcs-cartographie`, `docs/15-ia-sol-regles-mission.md`, each rule marked "measured" or "from the code"; `docs/14-*` is internal to the staff: cite its behaviour conclusions, never copy its technical content into VMCT) gives the behaviour of DCS's ground AI:

1. From DCS's code, not reproduced by its probe yet: a route with one segment DCS judges impossible (water, slope) is not installed at all; the group stays still, with no message. That fits "956 then 957 m".
2. Measured: a group holding a vehicle that cannot swim looks for a crossing 300 to 700 m away rather than crossing a river; a group takes the limits of its least capable vehicle (a merged convoy, `mergeIfClose`, armour and trucks in one group, is concerned).
3. Measured: a group starts 2 to 4 s after its order, even with 200 waypoints. Whether an order moved it can be judged 20 to 30 s later.
4. Measured: orders given every 2 s or less freeze a group.
5. Measured: an order given in the very frame a group is created is lost (3 out of 3); 5 s later it is taken. Routes passed inside the `addGroup` definition were not measured.
6. From DCS's code: an `On Road` point far from any road (more than about 10 m) makes the whole route fail. The convoy's retreat and several routes of `veafGroundAI.lua` (lines 1361, 2152, 2157, 2216, 2245, 2253) start `On Road` from the convoy's own position.

The session's prototype `lua/ia-sol/` (`ia_sol.lua`, `ia_sol_chassis.lua`, 21 tests outside DCS, run once in DCS) computes a validated path, sends it as one tight `Off Road` order and watches the group.

## Decided

David, 2026-11-22: a lot that fixes the cause.

Lands after FIX-CAMPAIGN-CONVOY-STUCK-IN-CONTACT (it builds on its pushes and its give-up rule). The integration branch is `feature/dynamic-campaign`: one branch and one pull request into it.

| # | Ticket |
|---|---|
| 01 | [`closeIn` aims at a reachable point on a checked path](tickets/01-close-in-on-a-reachable-point.md) |
| 02 | [An order is checked 30 s later](tickets/02-check-the-order-moved-the-group.md) |
| 03 | [No route starts `On Road` off the road](tickets/03-no-on-road-point-off-the-road.md) |

## Done

The three tickets, in one pull request into `feature/dynamic-campaign`; each ticket's `## Done` says what landed.
The prototype `lua/ia-sol/` of dcs-cartographie was not brought in as is: its A* on a grid, its chassis table and its watcher are more than a close in of a kilometre needs. Its segment check (water, slope along the drive) and its order rules (one order of a few `Off Road` points, 5 s after a group's creation, a check about 20 s after an order) are what came in, under VMCT's tests.
No `known-limitations.yaml` entry: nothing was measured in DCS by this lot; the behaviours used are cited in the code as measured or read by dcs-cartographie.
Waits for the in-game checks written in each ticket.
