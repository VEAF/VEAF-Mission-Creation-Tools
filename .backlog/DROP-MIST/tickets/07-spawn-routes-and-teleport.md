# 07 — Spawn, routes and teleport

Status: ⬜ ready — **gated by ticket 00**
Type: refactor

80 call sites over **726 MiST lines** — the functional core of the dependency, and the reason this lot
is a campaign rather than a ticket. Every VEAF spawn path ends up here.

## The list

| Function | Calls | MiST lines | What it does |
|---|---:|---:|---|
| `mist.dynAddStatic` | 18 | 102 | create a static object at runtime |
| `mist.dynAdd` | 17 | 222 | create a group at runtime |
| `mist.teleportToPoint` | 15 | 223 | move a group, route and all |
| `mist.goRoute` | 11 | 24 | push a route onto a group |
| `mist.getGroupRoute` | 11 | 70 | read a group's route |
| `mist.getGroupData` | 4 | 70 | read a group's record |
| `mist.respawnGroup` | 4 | 15 | respawn a group in place |

## Start from what is already known to be right

The #290 investigation read `mist.teleportToPoint` **end to end** and found it correct: it deep-copies
the route, translates every waypoint by the teleport delta, and hands the group to `dynAdd` with its
route attached. That is recorded in `ROADMAP.md` and it matters here for two reasons.

First, this is not a rewrite motivated by a bug — the behaviour to reproduce is the behaviour we have,
and any divergence is a regression rather than an improvement. Second, `teleportToPoint` **calls
`dynAdd`**, so the two are one problem: port `dynAdd` first and `teleportToPoint` becomes route
arithmetic on top of it.

## The dependency to settle first

`getGroupData` and `getGroupRoute` both read the mission database, which is ticket 05's subject.
**Ticket 00's question 3 decides whether this ticket depends on 05 or can precede it** — specifically
whether those two functions need the live record or the editor snapshot. Do not guess: the wrong answer
means porting `dynAdd` against an index that does not yet hold what it needs.

## Method

Rule 3 applies hard here. `mist.dynAdd`'s 222 lines handle every group category, every spawn variant
and a long tail of DCS quirks. Enumerate — from the code, not by sampling — which of those paths our 17
call sites actually reach, and port those. A category we never spawn is not ported.

**The enumeration is the deliverable, not a by-product.** Write it as a table in this ticket before
touching code: call site → group category → the `dynAdd` branch it takes. That table is also the test
matrix.

## Two traps

- **Coordinates.** `dynAdd` and `dynAddStatic` place objects, so
  [`docs/agents/dcs-coordinates.md`](../../../docs/agents/dcs-coordinates.md) is mandatory reading:
  `x`/`y`/`z` mean different things in a mission table and in the scripting API, and confusing them
  raises no error — only a wrong position. This is the single most likely way to ship a silent
  regression in this ticket.
- **Group and unit ids.** `dynAdd` allocates ids. Ticket 04 settles the allocation scheme for
  `getNextUnitId`; this ticket must use it, and must not collide with MiST's counter while both are
  loaded.

## Verification

Unit tests cannot see whether a group actually appeared at the right place in DCS. Two things carry that:

- `FEAT-DCS-SMOKE-HARNESS` (closed 2026-08-15) asserts through the bridge inside a running DCS and has
  already answered spawn-placement questions by machine rather than by a pilot. **Use it here** — this
  is exactly the lot it was built for.
- Whatever the harness cannot reach goes into [`DCS-SESSION-TODO.md`](../../../DCS-SESSION-TODO.md) with
  the commands to paste, not into a "verified" checkbox.

## Definition of done

- [ ] Ticket 00's question 3 is answered and the dependency on ticket 05 is settled
- [ ] The call-site → category → branch enumeration is written in this ticket **before** implementation
- [ ] Ported into a dedicated module behind `veaf.*` façades; `dynAdd` first, then `teleportToPoint` as
      route arithmetic over it
- [ ] 80 call sites migrated
- [ ] Lua tests covering every branch in the enumeration table, including a group category we spawn but
      MiST handled specially
- [ ] Position asserted against known coordinates, with the convention named in a comment
- [ ] Smoke-harness checks added for placement; anything it cannot reach filed in `DCS-SESSION-TODO.md`
- [ ] `stylua --check` and `luacheck` clean
