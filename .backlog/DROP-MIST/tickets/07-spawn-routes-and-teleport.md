# 07 — Spawn, routes and teleport

Status: ⬜ ready — ticket 00 answered 2026-08-28; no longer gated
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

## The dependency, settled

Ticket 00 read every database access these seven functions make. **None of them needs a live index.**

| MiST function | What it reads | Needs |
|---|---|---|
| `mist.getGroupRoute` | `MEgroupsByName` for the id, then walks `env.mission` | editor snapshot |
| `mist.getGroupData` | `groupsByName`, plus a partial-name match no VEAF caller relies on | editor snapshot |
| `mist.teleportToPoint` | `groupsByName` to fill in `country` / `category` when the caller omits them | editor snapshot |
| `mist.getCurrentGroupData` (the `teleport` action) | `unitsByName`, to enrich each unit with skill and callsign — with a complete native fallback in its `else` branch | nothing hard |
| `mist.dynAdd` | `groupsByName` / `unitsByName`, **only on the `clone` path**, to decide whether a name is free | the name registry |

All 15 `teleportToPoint`, 4 `respawnGroup` and both `veafSpawnAircraft` clone sites start from an
**editor** group name — a template, a Pedro, a carrier, an asset. VEAF never respawns or clones a group
it created itself.

So this ticket depends on **two named bricks from ticket 05**, not on its index:

1. the **editor snapshot** of groups and units, and
2. the **name registry** — which is what `veafSpawnAircraft.lua:788-789` hand-rolls today by deleting
   two `mist.DBs` entries so a dead AFAC's callsign can be reused. Port `dynAdd`'s uniqueness test
   against the registry, and that workaround disappears with it.

05 still lands first because both bricks live there. If 05 grows, those two can be split out and
reviewed on their own without holding this ticket.

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

- [ ] Ticket 05 has shipped the editor snapshot and the name registry, and this ticket uses them
- [ ] The call-site → category → branch enumeration is written in this ticket **before** implementation
- [ ] Ported into a dedicated module behind `veaf.*` façades; `dynAdd` first, then `teleportToPoint` as
      route arithmetic over it
- [ ] 80 call sites migrated
- [ ] Lua tests covering every branch in the enumeration table, including a group category we spawn but
      MiST handled specially
- [ ] Position asserted against known coordinates, with the convention named in a comment
- [ ] Smoke-harness checks added for placement; anything it cannot reach filed in `DCS-SESSION-TODO.md`
- [ ] `stylua --check` and `luacheck` clean
