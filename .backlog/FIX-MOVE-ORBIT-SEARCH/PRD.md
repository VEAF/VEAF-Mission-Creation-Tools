# FIX-MOVE-ORBIT-SEARCH — the orbit search assumes a three-point tanker route

Status: ⬜ ready

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

- [ ] The orbit is found on a route ending with a landing point
- [ ] VEAF's own three-point templates keep working (regression)
- [ ] A route with no orbit task reports it instead of guessing
- [ ] Which orbit wins when several exist, recorded here
