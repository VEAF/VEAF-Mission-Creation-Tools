# FIX-SPAWN-ANCHOR-AND-STATIC-SHIPS — three defects the post-merge review of FIX-TRIPACK-FIELD-REPORTS found

Status: ✅ done · archived 2026-09-28

Origin: 2026-09-07. Sourcery's weekly budget was spent when FIX-TRIPACK-FIELD-REPORTS shipped, so its
four PRs merged on CI alone. When the budget returned, David asked for the review that was owed.
#917 went through Sourcery; #918 and #921 were reviewed by agents instead, since one PR exhausted the
budget again. Between them: five real defects, three of which need a decision and got one.

Every finding below was re-verified by hand before this lot was written.

## What is wrong

### 1. A group that was moving comes up displaced

A combat zone's spawn translates **every unit of a group by one offset**, and that offset is measured
between two different *moments*: the anchor is the live position of the group's first unit, while the
spawner subtracts that same unit's **editor** position. The difference is whatever the unit has
drifted since the mission started, and it is applied to the whole group.

Measured in the harness: drift unit 1 by 100 m and all five units land 100 m out.

`initialize()` runs a few seconds into the mission, so a pre-placed ship already under way or a CAP
already airborne is affected; stationary ground units — Tripack's case — are not. This is the
residual half of what FIX-TRIPACK-FIELD-REPORTS ticket 04 fixed: it made both ends read the same
*source*, not the same *instant*.

**David's decision (2026-09-07): the group goes back to where the Mission Editor drew it**, always.
That is also what the docstring and the CHANGELOG already claim, so this closes a gap between the
code and its own description rather than opening a new behaviour.

### 2. A cold-and-dark aircraft comes back cold after a teleport

Ticket 05 taught the mission record to carry `uncontrolled` and `hidden`, which was right for a clone
and a respawn — MiST's editor database carried them. But `getCurrentGroupData`, the teleport's source,
starts from that same record, and MiST did the **opposite** there: for any group it had not itself
created, it forced `uncontrolled = false` and `hidden = false`
([`mist.lua:1040`](../../src/scripts/community/mist.lua)).

So an aircraft parked `uncontrolled` in the editor and moved by `_move group`, `veafSpawnObjects` or
an escort teleport came back flyable up to 6.19.0, and comes back cold now. A group hidden from the
F10 map stays hidden.

**David's decision: restore the previous behaviour.** Nobody asked for the change, and an aircraft
that arrives unusable is hard for a mission maker to diagnose.

### 3. A ship placed as scenery is still dragged ashore, and now nothing complains

Ticket 02 narrows the spawn-point search to water only when the element's category is `ship` — the
mission-table section the group was read from. A ship placed as a **static object** is in the `static`
section, so it keeps the land-only search and is moved onto dry land exactly as before.

And it is worse than the group case was: the downstream terrain check resolves `static` to
`ANY_TERRAIN`, which accepts `LAND`, so the hull spawns on the quay **silently**. The group case at
least failed loudly, which is how the whole defect was found.

Nobody is hit today — Tripack's mission has 103 statics and no ship among them — but the fix is
straightforward, because the data is there: a static unit carries its own DCS sub-type
(`Heliports`, `Fortifications`, `Cargos`, `Ships`…). Measured on his mission. What hides it is that
`veafMissionDb` overwrites that sub-type with the string `"static"`.

**David's decision: fix it now**, in this lot.

## Two corrections of record, no decision needed

- The in-game check queued for ticket 04 **cannot produce the numbers it asks for**: it says to run at
  `debug`, but the two positions it wants are logged at `trace`, and the offset it wants is logged at
  no level at all. As written it would spend a DCS session for nothing.
- Three sentences in the repository are false and were written by this session: "the offset is zero by
  construction" (docstring **and** CHANGELOG), which finding 1 disproves, and "MiST carried every one
  of these" about the forwarded fields — `taskSelected` and `communication` appear **zero** times in
  `mist.lua`. They are new design, not restorations.

## Scope

| # | Ticket | Type | |
|---|--------|------|---|
| 01 | [A respawn puts the group back where the editor drew it](FIX-SPAWN-ANCHOR-AND-STATIC-SHIPS.md) | fix | ✅ |
| 02 | [A teleport stops carrying the editor's cold-and-dark](FIX-SPAWN-ANCHOR-AND-STATIC-SHIPS.md) | fix | ✅ |
| 03 | [A ship placed as scenery looks for water](FIX-SPAWN-ANCHOR-AND-STATIC-SHIPS.md) | fix | ✅ |

## Constraints

- **The harness cannot see dispersion**: `dcs_mocks` answers `math.random()` with a constant `0`, so
  every draw lands on the centre whatever the radius. Any test about a radius must drive
  `dcs_mocks.setRandomSequence`, or it passes whichever way it is written.
- Ticket 01 changes observable behaviour for moving groups. Its test must assert the **built group's**
  unit positions with the anchor deliberately drifted — the case that exposed the defect.
- Ticket 02 must not undo ticket 05: a **clone** and a **respawn** keep carrying those fields; only the
  **teleport** path drops them. One test per verb, so the next reader cannot collapse them again.
- Lua coverage floor per the ratchet policy; both documentation languages if any page changes.

## Delivered

One branch, one PR. Each fix carries a test verified to fail against the code as it stood this
morning — the only reason to trust any of them:

| Mutation | What fell |
|---|---|
| the anchor back to the live position | the two drifted-anchor tests (100 m and 1 500 m of drift) |
| the teleport's clearing removed | `test_a_teleport_does_not_carry_the_editors_uncontrolled` |
| static-ship recognition disabled | `test_a_static_ship_is_not_left_on_the_quay`, with *placed at x=5, which is the quay* |

Three corrections of record went with them: the CHANGELOG's "offset zero by construction", the
provenance comment claiming MiST carried all eight forwarded fields (it carried seven, and neither
`taskSelected` nor `communication`), and the DCS-session item that asked for `debug` where the traces
are at `trace` and for an offset logged nowhere.

One latent defect fixed on the way: the refusal message in `_drawOrigin` called `table.concat` on
whatever `onTerrain` was handed, which raises if that is a string rather than a list — inside the
error path, where a raised error stops the script in DCS. `onTerrain` still has no caller, so it stays
latent; it was worth the one line because that message is the code that runs when things are already
going wrong. Found by the review of #918.

**Ticket 03 shipped as half of what it planned**, on re-reading the diff before committing. It was
also going to tighten the spawn's terrain check for a static hull; the search fix alone turns out to
be enough — the suite passes untouched — and tightening the check would have refused a `Ships` static
a mission maker had deliberately run aground. The reasoning is in the ticket.

## Post-PR review of this lot (#933)

Reviewed by an agent, Sourcery's budget still being spent. Six points, all acted on — and the first
is the same defect class this lot was opened to clean up:

1. **An orphaned comment.** Removing `:onTerrain()` from the spawn chain left the four comment lines
   that described it, hanging off the paragraph about `offsettingFirstWaypoint()` and asserting the
   opposite of what shipped: that the search and the validation agree, where ticket 03 says they
   deliberately do not. A confident false sentence, in a file whose invariants live in its comments.
   Removed.
2. **The teleport's clearing missed statics.** MiST applied its rule *before* splitting group from
   static (`mist.lua:1040`, ahead of the `objType == "group"` test), so a teleported static was
   covered too. The fix sat only on the group branch, leaving a static hidden in the editor coming
   back hidden — this ticket's own regression, surviving. Fixed, with a test.
3. **The "clone still carries it" test never cloned.** It read the record and asserted a field on it,
   so clearing `uncontrolled` in *every* verb would have left it green — precisely what it existed to
   forbid. Replaced by one that goes through `:clone()` and reads what reaches `coalition.addGroup`;
   verified by mutation.
4. **`anchor.alt` was taken back out.** A mission-table altitude is MSL under `alt_type = "BARO"` and
   **AGL** under `"RADIO"`, a runtime vec3's `y` is always MSL, and the record carries no `alt_type` —
   so there is no way to tell which one it holds. Reading AGL as MSL drops an aircraft into a random
   altitude band. The terrain height is what the branch returned before and what ground groups want.
   Better no altitude than a wrong one.
5. Two stale clauses, in the CHANGELOG and the docstring, still describing a liveness fallback that no
   longer exists. Corrected — both in text this PR had edited to remove a *different* false claim.
6. `staticCategory` sits one letter-order away from the spawner's existing `categoryStatic`, which
   does something else. Named in a comment rather than renamed: reusing that name would make a
   respawned static submit `category = "Ships"`, a behaviour change nothing here measured.

What the review checked and found clean: the offset really is zero now, `referencePositionOf` has one
caller and its position one consumer, the early `return nil` in `surfacesForZoneElement` is
behaviour-preserving, the `table.concat` hardening has no `and`/`or` trap, the CSAR no-record case is
unaffected, `staticCategory` is absent rather than nil-crashing for every non-static, and ticket 03's
reasoning for not tightening the validation holds — a `Ships` static run aground deliberately keeps
its declared position when the water search fails.

---

## Tickets, in full

## 01 — A respawn puts the group back where the editor drew it

Status: ✅ done

Type: fix

### The defect

`veafCombatZone.referencePositionOf` returns the **live** position of the record's unit 1, while
`VeafGroupSpawn._drawOrigin` subtracts that unit's **editor** position. The offset is therefore the
drift accumulated since mission start, and `_spawn` applies it to every unit of the group.

Measured: drift unit 1 by 100 m, all five units of `CMBT_ABU_MUSA_AIRPORT - AAA` land 100 m out.

FIX-TRIPACK-FIELD-REPORTS ticket 04 made both ends read the same **source**. This makes them read the
same **instant**.

### The fix

Return the anchor's editor position, which is the branch the function already has as its second
fallback. The live lookup is what `_drawOrigin` then undoes, so removing it makes the offset genuinely
zero — what the docstring and the CHANGELOG have been claiming.

David's call, 2026-09-07: a zone that respawns a group puts it back where it was drawn. A convoy that
had driven off returns to its start, which is the point of resetting a zone.

### Also in this ticket, because they are the same defect's paperwork

- The docstring's *"the offset is zero by construction and no divergence is possible"* and the
  CHANGELOG's *"l'offset est zéro par construction"* were false. They become true with this fix, so
  they stay — but the reasoning has to name the instant as well as the source.
- The `DCS-SESSION-TODO.md` item for ticket 04 asks for three numbers at `debug` level. Two are logged
  at `trace`, the third at no level at all. Either the item says `trace` and gains a logged offset, or
  it is dropped as unanswerable. It is the only open item of that ticket, so leaving it as-is spends a
  DCS session for nothing.

### Definition of done

- [x] A respawned group's units land on their editor positions, whatever the anchor's live position
- [x] Test with the anchor **deliberately drifted** — the case that exposed this; it must fail against
      today's code
- [x] The existing displacement suite still passes, including `#spawnradius=0` at exactly zero
- [x] The docstring and the CHANGELOG say what the code does
- [x] The DCS-session item is executable, or removed with the reason
- [x] `stylua --check` clean; `luacheck` via CI; Lua coverage floor per the ratchet

---

## 02 — A teleport stops carrying the editor's cold-and-dark

Status: ✅ done

Type: fix

### The defect

Ticket 05 added `uncontrolled` and `hidden` to the mission record so a **clone** and a **respawn**
would carry what the Mission Editor set — correct, and what MiST's editor database did.

But `veafDcsSpawner.getCurrentGroupData`, which the **teleport** verb reads, starts from that same
record and overwrites only `name`, `groupId`, `category` and `units`. So both fields now flow into a
teleport, where MiST did the exact opposite: for any group it had not created itself — i.e. every
editor group — it forced them off ([`mist.lua:1040`](../../src/scripts/community/mist.lua)):

```lua
if gfound == false then
  newTable.uncontrolled = false
  newTable.hidden = false
end
```

Verified: `grep` of the merged tree confirms the record now carries both, and nothing on the teleport
path clears them.

### What a mission maker sees

An aircraft parked cold and dark in the editor, moved by `_move group`, `veafSpawnObjects` or an
escort teleport, arrived flyable up to 6.19.0 and arrives cold now. A group hidden from the F10 map
stays hidden after being moved.

David's call, 2026-09-07: restore the previous behaviour. Nobody asked for the change, and an aircraft
that arrives unusable is hard to diagnose from the cockpit.

### The fix

`getCurrentGroupData` clears `uncontrolled` and `hidden` after copying the record — MiST's rule, at
MiST's place. Not by removing them from the record, which would undo ticket 05 for the clone and the
respawn that need them.

### Definition of done

- [x] A teleported editor group is submitted controlled and visible, whatever the editor set
- [x] A **clone** and a **respawn** still carry both fields — one test per verb, so the three cannot
      be collapsed into one behaviour by the next reader
- [x] `stylua --check` clean; `luacheck` via CI; Lua coverage floor per the ratchet

---

## 03 — A ship placed as scenery looks for water

Status: ✅ done

Type: fix

### The defect

Ticket 02 narrows the spawn-point search to water when the zone element's category is `ship`. That
category is the **mission-table section** the group was read from, so a ship placed as a *static
object* lives under `static` and keeps the land-only search: it is dragged onto dry land exactly as
before the fix.

And the silent half: the spawner's own terrain check resolves `static` to `ANY_TERRAIN`, which accepts
`LAND`, so the hull is created on the quay with **no error at all**. The group case failed loudly,
which is the only reason the defect was ever found.

### The data is already there

A static unit carries its own DCS sub-type. Measured on Tripack's mission:

| `category` on the static unit | count |
|---|---|
| `Heliports` | 55 |
| `Fortifications` | 48 |
| `Cargos` | 1 |
| `Helicopters` | 1 |

A static ship would be `Ships`. What hides it is `veafMissionDb.unitRecord`, which writes
`category = context.category` — the section name, `"static"` — over the unit's own sub-type.

So: carry the static's sub-type in the record under its own key, and let the surface decision read it.
Do not overload `category`, which every existing caller reads as the section.

Nobody is affected today — 103 statics in Tripack's mission, no ship — so this is prevention, and it
should not cost more than the data it already has.

### Definition of done

- [x] A static whose sub-type is `Ships`, in a combat zone with a spawn radius, searches on water
- [x] ~~Its terrain validation accepts water and refuses dry land~~ — **dropped deliberately, see
      below.** Fixing the *search* is enough: the hull is never offered the quay, so the validation has
      nothing left to refuse. Verified: the whole suite passes without touching it.
- [x] Every other static — `Fortifications`, `Heliports`, `Cargos` — is unchanged, asserted
- [x] The static's sub-type reaches the record without overloading `category`
- [x] `stylua --check` clean; `luacheck` via CI; Lua coverage floor per the ratchet

### One half of this ticket was written and then removed

The first implementation also handed the water surfaces to the spawn's own terrain check, so that the
validation would refuse dry land instead of accepting any surface. It worked, and it was taken back
out on re-reading the diff.

The defect needs two steps: the search drags the hull onto the quay, *then* the check accepts it. Fix
the first and the second has nothing to do — the suite proves it, passing unchanged with the
validation left alone.

And tightening the validation carries a risk the search fix does not: a mission maker who has
**deliberately** put a `Ships` static on land — a wreck aground on a beach, a hulk in a scrapyard —
would have had it refused outright, which is the very symptom this lot exists to remove, inverted.
Smaller change, no new way to fail.

---
