# FEAT-CLEAR-GROUND-AT-AUTHORING — when the tools place a group, they place it somewhere measured clear

Status: 📋 open — **two design decisions have to be made before any ticket can be written**, see
*Decisions to make first*. David asked for the lot on 2026-09-26 evening, after
[`FIX-PLACEMENT-IGNORES-SCENERY`](../FIX-PLACEMENT-IGNORES-SCENERY/PRD.md) ticket 11 reached its
ceiling.

Origin: ticket 11 fixed `veafUnits.settleGroup` at runtime and measured the result — 19 group alerts
and 76 blocked vehicles become 15 and 69 on GermanyCW-v6. Good, and nowhere near the target, for a
reason that is measured rather than guessed: **62 % of the vehicles still standing in trees belong
to groups `settleGroup` is never given**, and the ones it does see and cannot solve are places where
`Disposition` returns nothing at any clearance at all, down to 5 m.

## The rule this lot exists to enforce

David's arbitration, 2026-09-26, and it has two halves that must not be confused:

- **A position the mission maker drew stays where they drew it.** Unchanged since the arbitration of
  2026-08-27. Editor content is not this lot's business and must never be moved behind their back.
- **A position *the tools* chose is the tools' responsibility.** When a mission is authored through
  the MCP server and the VEAF tooling — not by a human placing a unit in the editor — putting a
  15-vehicle S-300 in a wood is a defect of ours, and it must be placed on ground measured clear,
  **at authoring time**.

The point of moving this to authoring time is that runtime is the worst possible place to ask.
`Disposition.getSimpleZones` is non-deterministic there, it ignores the search radius it is given,
and it returns **zero candidates** exactly where a group most needs help. At authoring time there is
no frame budget and no hurry.

**What makes this tractable:** the *small* probe — "is there a patch of 5 m free within 20 m of this
point?" — is the one use of the singleton measured **reliable and deterministic**: 12 repetitions on
the same points gave 0/12 against 12/12, with identical candidate counts
([`known-limitations.yaml`](../../src/python/veaf-tools/veaf_libs/data/known-limitations.yaml),
`disposition-getsimplezones-is-a-lottery`). A catalogue built by sweeping with that probe rests on
the only thing DCS does dependably here. The large query, which asks for a whole clearing at once,
is the lottery — and it is what this lot must avoid, not imitate.

## The two halves, and how they fit

**A — the MCP offers to launch DCS and check what it just generated.** The server produces the
`.miz`, DCS loads it, the blocked units are read back, and the result is reported or corrected. It
is the **only** way to validate the end result for real. It costs a DCS instance and a mission load
measured in minutes, it never runs in CI, and it *observes* rather than places.

**B — a catalogue of clear positions, swept once with DCS and served to the MCP.** Each retained
point carries **the radius actually clear around it**, so the server can ask for "somewhere near
Wittstock that holds 15 vehicles" and get candidates with no DCS running, instantly, offline and in
CI. It places correctly the first time instead of repairing at spawn. It costs the sweep, the
storage, and it ages when ED retouches a map.

**B is the foundation, A is the gate, and B comes first** — B attacks the cause where A only
observes, and B is the half that works without DCS.

## Decisions to make first

Neither is obvious, and David left both open on 2026-09-26 rather than guess. **No ticket should be
written until they are settled.**

1. **Sweep perimeter.** The whole map on a fixed grid, or only around what matters — combat zones,
   airfields, road axes? The first is exhaustive and answers anywhere; the second is the difference
   between hours and minutes of sweeping, and leaves holes wherever nobody thought to look. The cost
   of a sweep has **not been measured**: the probe's throughput was going to be timed on 2026-09-26
   and DCS disconnected first. Measure it before deciding — the answer may make the question moot.
2. **Granularity.** Store the clear radius per point, or a plain free/occupied flag? A radius is what
   lets one catalogue serve a lone Ural and a 15-vehicle S-300 from the same data, and the groups
   this lot exists for are precisely the large ones. A flag is smaller and simpler and cannot answer
   the question that matters. Settle it knowing that **a group's footprint moves by up to 38.8 m
   between draws** ([`FIX-PLACEMENT-IGNORES-SCENERY` ticket 11](../FIX-PLACEMENT-IGNORES-SCENERY/tickets/11-settle-verifies-the-candidate-it-trusts.md)),
   so whatever is stored has to be read with a margin rather than exactly.

## Decided

3. **Both distribution modes.** A catalogue per map, versioned in VMCT so everyone benefits without
   owning the terrain, **and** generation on demand on the workstation of whoever authors a mission,
   for a map or an area the versioned catalogue does not cover. David, 2026-09-26.
