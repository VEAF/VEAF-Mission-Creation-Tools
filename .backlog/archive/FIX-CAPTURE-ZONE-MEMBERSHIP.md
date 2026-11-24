# FIX-CAPTURE-ZONE-MEMBERSHIP — a convoy takes a zone without becoming its garrison: two definitions of "in the zone"

Status: ✅ done — 2026-10-10, seen in game (R47 item 6) · archived 2026-11-24

## Found

David, 2026-10-08, *Kolkhida* mission 1, built from `develop` at `4ab6bd0d` (with FIX-ASSAULT-CONVOY-FINDINGS ticket 03's measurement): "Poti n'a pas absorbé le convoi".

The logging shipped by FIX-ASSAULT-CONVOY-FINDINGS ticket 03 gives the cause:

```text
17:36:13 CAMPAIGN absorbConvoy: zone [Poti] taken by blue: 2 assault convoy record(s) to look at
17:36:13 CAMPAIGN absorbConvoy: zone [Poti]: convoy [Kobuleti - Poti assault] of blue, ended nil, group exists, 9 unit(s) alive, 0 inside, nearest 2117 m from the centre (radius 2000)
17:36:13 CAMPAIGN capturedBy: zone [Poti]: no assault convoy of blue in it, its garrison is drawn from the reserve
17:36:13 CAMPAIGN drawGarrison: zone [Poti]: garrison drawn, 24 unit(s)
```

The capture before it was run by the convoy's own units (`held by blue (Kobuleti - Poti assault - MBT Merkava IV #5)`, `… ATGM VAB Mephisto #9`, `… Truck M939 Heavy #8`, `… SPAAA Vulcan M163 #10`).

Measured right after, in the running mission through the fiddle hook (read-only): `world.searchObjects(Object.Category.UNIT, SPHERE { point = Poti's centre (y = 0), radius = 2000 })` returns the convoy's 9 units at **2036 to 2077 m** from the centre, 2D and 3D alike (units at y = 5 m).

## Causes

1. **Two definitions of "in the zone".** `VeafCampaignZone:sidesPresent` (the capture) trusts `world.searchObjects` on a sphere, which returns units up to about 4 % beyond its radius; `veafCampaign.absorbConvoy` measures the exact 2D distance. A convoy standing just outside the radius takes the zone, and is then not found in it: the zone draws a garrison from the reserve and the convoy stays "on the road".
2. **The convoy stops at the zone's edge.** All nine units halted together between 2.04 and 2.08 km from Poti's centre, not at the centre the campaign sends them to (`veafNamedPoints` "CAMPAIGN Poti"). Not explained yet: the road's end, the convoy's destination handling, or something stopping it on arrival.

Same picture on the earlier run of the day (FIX-ASSAULT-CONVOY-FINDINGS): measured after the fact, the units stood 0–90 m from the centre — they had driven on after the capture.

## Tickets

| # | Ticket | Status |
|---|---|---|
| [01](FIX-CAPTURE-ZONE-MEMBERSHIP.md) | One definition of "in the zone" for the capture and the absorption | ✅ |
| [02](FIX-CAPTURE-ZONE-MEMBERSHIP.md) | The assault convoy drives into the zone, not to its edge | ✅ |
| [03](FIX-CAPTURE-ZONE-MEMBERSHIP.md) | `world.searchObjects` overshoots its sphere: a DCS trap, measured | ✅ |
| [04](FIX-CAPTURE-ZONE-MEMBERSHIP.md) | An assault convoy strong enough to fight presses on to its target zone | ✅ |
| [05](FIX-CAPTURE-ZONE-MEMBERSHIP.md) | A weapon is never a threat | ✅ |

## Related

- `FIX-ASSAULT-CONVOY-FINDINGS` (#1108), ticket 03: the measurement that found this.
- `FEAT-OPPOSITION-SCALES-WITH-PLAYERS` ticket 04 (#1100): the assault convoys.

## Tickets, in full

## 01 — One definition of "in the zone" for the capture and the absorption

Status: ✅ done

- The units that took the zone become its garrison: `absorbConvoy` takes the convoy's units among those the capture's own search found, rather than re-measuring with another rule — or both go through one function. Whatever the choice, the capture and the absorption can no longer disagree on a unit.
- Decide, and say in the code, whether "in the zone" keeps `searchObjects`' slack or filters it to the exact radius; if filtered, ticket 02 must bring the convoy inside, or a convoy at the edge would never take the zone.
- Lua tests: a convoy whose units the search returns at 2036–2077 m of a 2000 m zone is absorbed (no `drawGarrison`, no reserve spent); the existing absorption and capture tests still pass.
- `CAMPAIGN.md` / `.en.md` if what "in the zone" means for a capture changes.

## 02 — The assault convoy drives into the zone, not to its edge

Status: ✅ done — seen in game 2026-10-10

**Measured 2026-10-10** (R47 item 6, `D:\dev\_VEAF\tmp\dcs-session-2026-10-10`, fiddle hook): the blue convoy of 10 halted about 2.1 km from Poti's centre while the zone was being taken (`nearest 2117 m from the centre`, `10 inside`), became its garrison (`holds [Poti]: 10 unit(s) become its garrison`, no garrison drawn from the reserve), then drove on to the centre: nearest unit 0 m, 10 of 10 alive.

- Find why the blue convoy's nine units stopped together 2.04–2.08 km from Poti's centre (zone radius 2 km): its route's last point (`veafSpawn.spawnConvoy` towards the named point "CAMPAIGN Poti"), the road network near the port, `veafGroundAI`'s arrival handling, or the campaign itself. Read the code first; measure in a test mission (a copy of `D:\dev\_VEAF\_campaigns\campaign-kolkhida`, never David's live session) only for what the code cannot settle — prepare the mission and ask David to run it, never launch DCS yourself.
- Make the convoy end its drive well inside the zone (on a road point inside the radius when the centre is off-road, as Poti's port is).
- Lua tests on the destination chosen for a zone whose centre is off the road.

### Found from the code (2026-10-08)

- The route already ends at the centre. `veaf.generateVehiclesRoute` drives on the road to `END`, the road point nearest the named point "CAMPAIGN Poti" (`land.getClosestPointOnRoads`), then off road (`Diamond`) to `T_END`, the centre itself. Since `END` is the nearest road point to the centre, no road point lies closer: "a road point inside the radius" exists only if `END` is already inside.
- Nothing in VMCT stops a convoy there. The campaign never re-routes it; `veafSpawn.convoyArrivalWatchdog` only watches multi-point itineraries; `veafGroundAI` logged no contact for the blue convoy before 17:37:43, 50 s after the halt was measured, and its alerted state does not stop a convoy.
- So the halt at 2.04–2.08 km is on the DCS side, and the code cannot say which: `END` lying ~2.04 km from the centre with the column pausing there before its off-road leg (on the earlier run it did go on, to 0–90 m), or the column blocked — the 24-unit garrison wrongly drawn at the capture was spawned across Poti 40 s before the measurement.
- What this lot changes regardless: a convoy halted at the edge now becomes the garrison (ticket 01), no garrison is spawned under it any more, and a convoy in contact drives into the zone (ticket 04). Each departure now logs `its road ends N m from [<zone>]'s centre (radius R), then <action> to the centre`.

### To measure in DCS

Test mission (a copy of *Kolkhida* mission 1, built from this branch, `assault_seconds: 30`): `D:\dev\_VEAF\tmp\fix-capture-zone-membership\Kolkhida-capture-test_20261008.miz`. Its `mission-script.lua` logs a `PROBE Poti` line every 15 s and a `PROBE VERDICT` line once the blue convoy has stood still for a minute.

### Measured on the squadron's flight (2026-10-08, evening)

*Kolkhida* mission 1, built by veaf-tools `6.28.1-kolkhida7` (it logs `logRoadEnd`, so it carries this lot's tickets 01 and 04), flown on `private1`; log and state kept in `D:\dev\_VEAF\_campaigns\campaign-kolkhida\missions\mission-01\` (see `FIX-CAMPAIGN-MISSION-1-FINDINGS`).

- `19:29:15 UTC`: `its road ends 163 m from [Poti]'s centre (radius 2000), then Diamond to the centre` — `END` is well inside the zone, so the edge is not the road's end.
- `20:44:44 UTC`: `9 unit(s) alive, 9 inside, nearest 2123 m from the centre`, then `9 unit(s) become its garrison` — ticket 01 holds in game.
- In the state files of 22:45 and 23:00 local time (UTC+2), the Poti garrison's units stand **2 123 to 2 182 m** from the centre (Poti at 42.15 N 41.67 E, `latlon_to_xy`), 16 minutes after the capture.

So the column halted at the edge again, with its road going on to 163 m.
To settle before concluding: whether a garrison's positions in the state file are read live at each write or frozen at absorption.

## 03 — `world.searchObjects` overshoots its sphere: a DCS trap, measured

Status: ✅ done

- `known-limitations.yaml`, `kind: dcs`: a `SPHERE` search of radius 2000 m returned units at 2036–2077 m of its centre (2D and 3D, units at y = 5 m), Caucasus, 2026-10-08, *Kolkhida* mission 1 — what it broke (a zone taken by a convoy that then did not become its garrison), and the workaround (filter by exact distance, or treat the search result as the definition everywhere, never mix the two).
- Regenerate `docs/agents/dcs-runtime-traps.md`.
- Update the known limitation `a-captured-zone-may-draw-a-garrison-under-its-convoy` (FIX-ASSAULT-CONVOY-FINDINGS) with the cause, and set its `fixed_in` when ticket 01 lands.

## 04 — An assault convoy strong enough to fight presses on to its target zone

Status: ✅ done

Measured live on *Kolkhida* mission 1 through the fiddle hook (read-only), mission time 07:45: the red assault convoy `Senaki - Poti assault` is in groundAI state 3 (fighting). Its 7 armed vehicles (ZTZ96B ×2, BMP-2, Chieftain_mk3, CHAP_T90M, Tigr_233036, BMP-3) are stopped (speed 0.0) 2761–2940 m from Poti's centre. Its nearest threats (Poti's garrison: LAV-25, Strykers, Marder; the blue convoy's VAB Mephisto) are 1706–1815 m away. It has 18 recent threats and its last contact is 0 s old: contact never ends, because Poti holds the 24-unit blue garrison and the blue convoy, always in sight.

Cause, from the code: `ConvoyUnitHandler:fight` (`veafGroundAI.lua`) drives to `ASSAULT_STANDOFF` (900 m) of the threat of the moment, or holds; `standDown` and `resume` only come after `QUIET_DELAY` without contact, so a convoy in permanent contact never resumes its route to the zone.

- An assault convoy (one the campaign sent, with a target zone) that `convoyShouldFight` judges strong enough keeps moving toward its target zone while engaging. A plain convoy keeps today's behaviour; a weaker one still falls back.
- Lua tests: an assault convoy in permanent contact but stronger keeps closing on its target zone and ends inside it; a weaker one falls back; a non-assault convoy is unchanged.
- `veafGroundAI.md` / `CAMPAIGN.md` (FR + EN).

## 05 — A weapon is never a threat

Status: ✅ done

Measured on the same convoy (fiddle hook, read-only): its threat list holds `weapons.shells.M61_20_HE_gr strength=inf at 3697 m from Poti`. The hit event path records the weapon object, not the unit that fired it. Counted for an infinite strength, such an entry can make a convoy fall back for nothing.

- Record the shooter (the weapon's launcher), or nothing when it cannot be resolved; never a `Weapon` object.
- Lua tests: a hit whose initiator is a shell records the firing unit, or no threat; a convoy is not made to fall back by it.
