# FIX-SPAWN-ANCHOR-AND-STATIC-SHIPS — three defects the post-merge review of FIX-TRIPACK-FIELD-REPORTS found

Status: ✅ done

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
| 01 | [A respawn puts the group back where the editor drew it](tickets/01-respawn-anchors-on-the-editor-position.md) | fix | ✅ |
| 02 | [A teleport stops carrying the editor's cold-and-dark](tickets/02-teleport-drops-uncontrolled-and-hidden.md) | fix | ✅ |
| 03 | [A ship placed as scenery looks for water](tickets/03-static-ships-look-for-water.md) | fix | ✅ |

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
