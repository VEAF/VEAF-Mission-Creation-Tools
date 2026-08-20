# FIX-MOVE-ORBIT-SEARCH — the orbit search assumes a three-point tanker route

Status: ✅ done

Shipped in 6.15.12. Closed without an in-game gate: the fix is a route-data search, entirely covered by
unit tests over real route shapes (a VEAF template, a Liberation-style long route, orbit-first,
orbit-last, several orbits, Circle vs Race-Track). Nothing here depends on DCS behaviour the mocks
cannot model — unlike the escort task of #107, which is exactly why *that* one needed a flight.

Origin: [#248](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/248), reported by Maveric.

## The defect

`veafMove` looks at the **last three points** of a tanker's route to find the orbit, expecting it on
the second-to-last. That holds for VEAF's own templates and breaks on a DCS-Liberation tanker, whose
route ends with a landing point — so the orbit is looked for where it is not.

## Scope

Find the orbit **whatever the route length**: search for the waypoint carrying an orbit task rather
than counting backwards from the end. A route may hold more than one; decide which wins (the first,
the longest, the one nearest the requested position) and say why.

Refuse loudly when no orbit task is found, rather than adjusting the wrong waypoint — moving a tanker
to the wrong place is worse than telling the player it cannot be done.

## Definition of done

- [x] The orbit is found on a route ending with a landing point
- [x] VEAF's own three-point templates keep working (regression)
- [x] A route with no orbit task reports it instead of guessing
- [x] Which orbit wins when several exist: **the first**, recorded in [ticket 01](tickets/01-search-for-the-orbit-task.md) with why "nearest the marker" was rejected

## One thing found while implementing, not in the original scope

`moveTanker` **overwrites** the waypoint after the orbit, treating it as the far end of the refuelling
leg. Searching for the orbit anywhere in the route raised the question of whether that is still right
when the orbit sits mid-route. It is, by DCS's semantics for a `Race-Track` orbit — but **not** for a
`Circle` orbit, which would have had the following waypoint silently redrawn, and on a Liberation tanker
that could be the landing point. Guarded, and Maveric's postscript about "the other tanker
manipulations" is answered: there are two commands and they share the helper.
