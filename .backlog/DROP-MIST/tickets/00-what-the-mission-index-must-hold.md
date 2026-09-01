# 00 — What the mission index must actually hold (spike)

Status: ✅ done — 2026-08-28, findings in the PRD
Type: chore

A **measurement ticket**. It writes no production code; it answers three questions whose answers decide
the shape of tickets 05 and 07. Deliverable: a findings section appended to the PRD, and tickets 05 and
07 rewritten against it.

## Why it comes first

`mist.DBs.units` carries **33 write sites** inside MiST, so the table is maintained at runtime. Two of
our three consumers demonstrably do not care — [`veaf.lua:2769`](../../../src/scripts/veaf/veaf.lua) and
[`veafInterpreter.lua:156`](../../../src/scripts/veaf/veafInterpreter.lua) both walk it **once at init**
to build their own index, and `veafInterpreter` says it is *"liberally adapted from MiST"*. The third
consumer *writes* to it: [`veafSpawnAircraft.lua:788`](../../../src/scripts/veaf/veafSpawnAircraft.lua)
deletes two entries by hand so an AFAC can be respawned under a name it already used.

Nobody has established **who reads those entries back**. Until that is known, ticket 05 cannot decide
whether the index needs runtime maintenance for units spawned by third parties, or only for the ones we
create ourselves.

## Question 1 — who reads a dynamically added record?

Enumerate, from the code rather than by sampling, every read of `unitsByName`, `groupsByName`,
`groupsById` and `unitsByNum` — the 11 direct sites plus the six `veaf.lua` façades and each of
*their* callers. For each, classify what it needs:

- **pre-placed only** — the record exists in `env.mission`, a startup index suffices;
- **also for units we spawned** — the index must be updated when we create a group;
- **also for units a third party spawned** — late activation, CTLD, Foothold, another script, or a
  player taking a slot; the index needs the birth event.

The count in the third bucket is the finding. If it is zero, ticket 05 loses its whole event path.

## Question 2 — does MiST's birth handler even see AI spawns?

[`mist.lua:1642`](../../../src/scripts/community/mist.lua) guards the queue push with
`event.initiator:getPlayerName() ~= ""`. In Lua, `nil ~= ""` is true, so the guard's effect depends
entirely on whether DCS returns `nil` or `""` for an AI unit — which is not documented and must be
measured, not reasoned about.

Measure it: in a running mission, on an AI unit's birth event, log `type(getPlayerName())` and its
value. Two outcomes, both actionable:

- returns `nil` → AI spawns **do** go through the event path;
- returns `""` → AI spawns are skipped by the handler and only caught by the `verifyDB()` poll, which
  means MiST has a hole there, and that hole is the likely reason
  `veafSpawnAircraft.lua:788` has to intervene by hand.

Needs DCS started. Add it to [`DCS-SESSION-TODO.md`](../../../DCS-SESSION-TODO.md) rather than blocking
the ticket: questions 1 and 3 can be answered without the game, and they carry most of the decision.

## Question 3 — what does `getGroupData` / `getGroupRoute` read the DB for?

`mist.getGroupData` (70 lines, 4 calls) and `mist.getGroupRoute` (70 lines, 11 calls) are inputs to
ticket 07, and both read the database. Establish whether they need the *live* record or the editor
snapshot, because that decides whether ticket 07 depends on ticket 05 or can precede it.

## Definition of done

- [x] Every read of the four record tables is enumerated from the code and classified into the three
      buckets, with counts — **26 sites**, bucket A 20, bucket B 0 reads, bucket C 0 for AI spawns and
      5 for players
- [x] The dependency direction between tickets 05 and 07 is settled and written down — 07 needs two
      bricks from 05 (editor snapshot, name registry), not its index
- [x] Question 2 is either answered, or filed in `DCS-SESSION-TODO.md` with the exact log line to add —
      **it no longer decides the design**; filed as item 22, as an observation about
      `veafAirWaves.lua:791`
- [x] Findings appended to the PRD; tickets 05 and 07 rewritten against them
- [x] No production code changed by this ticket

## What it cost the campaign, in one line

Ticket 05 loses its AI birth-event path and half its surface; ticket 07 is unblocked; two dead pieces of
code (`veaf.mist.getUnitData`, `veafTransportMission.resetAllCargoes`) are queued for removal; and the
lot no longer waits on a DCS session.

## Question 2, answered in game 2026-08-28

`DCS-SESSION-TODO` item 22 is closed, and the answer clears `veafAirWaves` rather than condemning it.

Probed over **every unit in a running mission** — 346 of them, on Caucasus, DCS 2.9:

```
total=346  nonNil=1  →  "A-10C Kobuleti -1"  type=string  ["New callsign"]
```

**`getPlayerName()` returns `nil` for an AI unit**, not an empty string: 345 AI units, all `nil`, and
the single non-`nil` answer was the human slot. That last part is what makes the measurement worth
anything — the probe demonstrably could tell a player from an AI, so `nil` everywhere else is a result
and not a broken check.

So [`veafAirWaves.lua:791`](../../../src/scripts/veaf/veafAirWaves.lua) — `if dcsUnit:getPlayerName() then`
— is **correct as written** on this build. Air waves do not count AI aircraft as players, and no fix lot
is needed. The suspicion recorded in item 22 is closed, not deferred.

The index's own filter (`if p and p ~= "" then`) stays as designed: it is right whichever value DCS
returns, and it does not depend on this measurement holding for every future build.
