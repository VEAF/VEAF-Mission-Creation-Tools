# FIX-MOVE-ORBIT-SEARCH — the orbit search assumes a three-point tanker route

Status: ✅ done · archived 2026-09-28

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
- [x] Which orbit wins when several exist: **the first**, recorded in [ticket 01](FIX-MOVE-ORBIT-SEARCH.md) with why "nearest the marker" was rejected

## One thing found while implementing, not in the original scope

`moveTanker` **overwrites** the waypoint after the orbit, treating it as the far end of the refuelling
leg. Searching for the orbit anywhere in the route raised the question of whether that is still right
when the orbit sits mid-route. It is, by DCS's semantics for a `Race-Track` orbit — but **not** for a
`Circle` orbit, which would have had the following waypoint silently redrawn, and on a Liberation tanker
that could be the landing point. Guarded, and Maveric's postscript about "the other tanker
manipulations" is answered: there are two commands and they share the helper.

---

## Tickets, in full

## 01 — Find the orbit by looking for it, not by counting backwards

Status: ✅ done
Type: fix

Closes [#248](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/248), reported by Maveric.

### The defect

`veafMove._getTankerRouteData` ([`veafMove.lua:237`](../../src/scripts/veaf/veafMove.lua:237)) takes
the **last three** waypoints of a tanker's route and assumes the orbit is on the middle one:

```lua
point1 = points[#points - 2],
point2 = points[#points - 1],   -- assumed to carry the Orbit task
point3 = points[#points],
```

That holds for VEAF's own templates, whose route *is* [approach, orbit, leg end]. A DCS-Liberation
tanker has a longer route ending with a landing point, so the second-to-last waypoint carries no orbit
task, and both commands refuse: *"has no ORBIT task defined"*.

**It answers Maveric's postscript too** — *"potentiellement le faire pour les autres manipulations de
tanker"*. There are two, `changeTanker` and `moveTanker`, and they already **share** this helper, so
both are fixed at one point.

### Decisions the PRD asked to be recorded

**Which orbit wins when a route has several: the first one.** A tanker route has one working orbit; if
there are several, the first is the one the tanker reaches first, so it is the one that is active or
imminent — which is what a player asking to change tanker parameters means. *"The one nearest the
requested position"* was considered and rejected: it is appealing for `moveTanker`, meaningless for
`changeTanker` (which moves nothing), and having the two commands disagree about which orbit they are
talking about would be worse than a rule that is occasionally not the one you wanted.

**No orbit task: refuse, and say so.** Already the behaviour, but for the wrong reason — it refused
because the second-to-last waypoint happened not to carry one. Now it refuses because the route
genuinely has none. Moving a tanker to the wrong place is worse than telling the player it cannot be
done.

**`point1` and `point3` become optional.** They are the waypoints before and after the orbit. An orbit
on the first or last waypoint of a route is legal, and refusing such a route would trade one false
refusal for another.

### The trap this uncovered, which the PRD did not name

`moveTanker` **overwrites** the waypoint after the orbit, using it as the far end of the refuelling leg
([`veafMove.lua:530-533`](../../src/scripts/veaf/veafMove.lua:530)). On a VEAF template that waypoint
*is* the leg end, so overwriting it is right. Searching for the orbit anywhere in the route raises the
question of whether it is still right when the orbit sits in the middle of a longer route.

It is — **by DCS's own semantics**: an `Orbit` task with a `Race-Track` pattern flies between the
waypoint carrying the task and the **next** waypoint. So the waypoint after the orbit is the leg's other
end by construction, on a Liberation route as much as on a VEAF one.

**Except for a `Circle` pattern**, which orbits one point and gives the next waypoint no orbit role at
all. Overwriting it there would silently redraw the route. So the pattern is now consulted: `Circle`
leaves the following waypoint alone and logs that it did. Nobody has reported a circling tanker — this
is a guard against a defect the fix would otherwise have introduced, not a reported bug.

### Definition of done

- [x] The orbit is found on a route ending with a landing point
- [x] VEAF's own three-point templates keep working (regression)
- [x] A route with no orbit task reports it instead of guessing
- [x] Which orbit wins when several exist, recorded above
- [x] A `Circle` orbit does not have the following waypoint overwritten
- [x] Lua tests for each of the above

---
