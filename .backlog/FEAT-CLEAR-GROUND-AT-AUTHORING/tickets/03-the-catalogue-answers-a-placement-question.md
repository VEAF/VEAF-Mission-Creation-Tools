# 03 — the catalogue answers "where does a group this size fit, near here?"

Status: ⬜ ready — depends on ticket 02
Type: feat

## What this builds

The read side. Given a point, a search radius and a required clear radius, return the candidate
positions that satisfy them, nearest first. No DCS running, no `Disposition`, no lottery — the
terrain was measured once and is now just data.

**Read the stored radius with a margin, never exactly.** A group's footprint moves by up to
**38.8 m** between draws
([ticket 11](../../FIX-PLACEMENT-IGNORES-SCENERY/tickets/11-settle-verifies-the-candidate-it-trusts.md)),
so a group asking for 150 m must be served points comfortably above it, and the size asked for
should be the group's **worst-case** footprint rather than a drawn one.

**On-demand generation** (decision 5, second half): when the versioned catalogue does not cover a
map or an area, this path must say so, and the tooling must offer to sweep it locally rather than
silently returning nothing.

## Definition of done

- [ ] A query returns candidates ordered by distance, filtered on the required clear radius
- [ ] The margin applied over the stored radius is justified by the 38.8 m measurement rather than
      chosen by feel
- [ ] A query outside the catalogue's coverage is **distinguishable** from a query that searched and
      found nothing. They are different answers, and ticket 04 acts on them differently
- [ ] Querying is fast enough to run per group while a mission is being built, measured rather than
      assumed
- [ ] Python tests green
