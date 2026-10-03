# 04 — Refuse the FARP when the escort cannot be placed

Status: ✅ done — verified in game 2026-10-03 (R19): in a dense wood the `-farp` is refused with "no clear ground for its escort"; on open ground the escort stays beside the FARP's props

David, 2026-08-27: *"les escortes (farp) doivent être placées intelligemment, ou le farp est refusé si
c'est pas possible (avec un message)"*.

## This reverses a written decision, deliberately

[`veafGrass.lua:332`](../../../src/scripts/veaf/veafGrass.lua), the docstring of `findClearBearing`:

> *"Falls back to the requested angle at scale 1 when nothing is clear anywhere — **a FARP that refuses
> to exist because it is crowded would be worse than one placed imperfectly** — but says so at info,
> because that fallback is exactly how a group ends up on an apron."*

That fallback is not an oversight. `FIX-FARP-ESCORT-PLACEMENT` went through **five rounds of changes,
four of them adjusting how aggressively the placement refuses ground**, and its PRD states that *"a fix
that quietly moved every FARP in every existing mission would have been a worse outcome than the
defect"*. The 2026-08-24 in-game session verified both halves, and the non-regression half — *"c'est bon,
rien n'a bougé"* — mattered more than the reported case.

David's ruling stands: the sentence the fallback protects against is the wrong trade, because a group
standing on an apron is a decorative escort. But the lot inherits that history, so the refusal must be
**narrow and loud**, not broad and silent, and the non-regression must be proven the same way.

## What this ticket does

`findClearBearing` currently returns `baseAngle, 1` when nothing is clear anywhere. It gains a way to
say *"nothing is clear"* distinctly from *"here is a bearing"*, and the FARP path acts on it by refusing
the FARP with a translated message.

Three design points to settle before coding:

- **Who refuses — on two axes, not one.**

  *Axis 1, which piece.* `findClearBearing` serves four callers inside the layout — escort, tents, props,
  windsock (`veafGrass.lua` 1478, 1568, 1631, 1728) — and only the **escort** is meant to abort a FARP.
  The windsock's bearing is explicitly free (David's earlier call: nothing reads its position).

  *Axis 2, which FARP.* **`veafGrass.buildFarpUnits` has exactly two callers**, and David's ruling 3
  splits them:

  | Caller | What it builds | On an unplaceable escort |
  |---|---|---|
  | [`veafSpawnGround.lua:105`](../../../src/scripts/veaf/veafSpawnGround.lua), inside `spawnFarp` | the `-farp` command's FARP | **refuse, with a message** |
  | [`veafGrass.lua:586`](../../../src/scripts/veaf/veafGrass.lua), inside `buildFarpsUnits` — scheduled at startup, walking the units named `FARP …` | **the editor's static FARPs** | **keep today's fallback** |

  *"c'est applicable au spawn (`-farp`) mais pas à ce qui est placé dans l'éditeur de mission (combat
  zone, farp statiques, etc.)"* — a marker command has a user standing there who can read the message and
  re-place the marker; a static FARP in the editor has nobody, and refusing it at mission load would
  remove furniture from a mission that has always worked.

  So the refusal is a **parameter of `buildFarpUnits`, set by its caller** — not a behaviour of
  `findClearBearing`, which only reports that nothing was clear. That the two callers map exactly onto the
  two sides of the ruling is what makes this implementable rather than a judgement call per call site.
- **What "refused" means for a FARP that is already half built.** The layout code places several things
  in sequence. Establish whether the escort is decided **before** anything is created; if not, the
  refusal has to either move earlier or clean up what it already spawned. A half-built refused FARP would
  be worse than either behaviour.
- **The message.** Translated through `veaf.t` with a new i18n key in both locales, saying *why* — no
  clear ground for the escort — and naming the FARP, so a mission maker can act on it. Do not emit a
  bare failure: this message is the only thing standing between the mission maker and a silently missing
  FARP.

## The measurement, run in game 2026-08-28 — the number this ticket was waiting for

Four `-farp` markers on `VEAF-session-2026-08-27` (Caucasus), one per case, ticket 03's scenery
criterion in force. Read off `dcs.log`, filtered on `findClearBearing` and `FARP escort`:

| Marker | Case | Tier that answered | Escort placed at |
|---|---|---|---|
| `T1-DEGAGE` | open ground, nothing within a kilometre | scenery cloud | bearing 0 → **25**, 1.12x |
| `T2-PRES-STATIQUE` | ~150 m from a static FARP | scenery cloud | bearing 0 → **219**, 1.155x |
| `T3-VILLAGE` | inside a village | scenery cloud | bearing 0 → **54**, 1.16x |
| `T4-FORET` | dense woods | bearing walk | bearing 0 → **-15**, 1x |

**`nothing clear at any bearing or distance` fired 0 times out of 4** — including in dense woods, the
case built to break it. `Disposition.getSimpleZones unusable` never appeared either, so the forest half
of the criterion was live throughout and the figure is not an artefact of an inert check.

**So the refusal is a rare path, not the common one, and this ticket is a fix rather than a
mission-breaker.** It can fire on the first exhaustion; no widened search is needed to keep the
refusal narrow, because exhaustion is already narrow.

Two caveats worth carrying, neither of which changes that conclusion:

- The run happened on a mission that loaded **two** VEAF configurations at once (a leftover v5
  `missionConfig.lua` beside the generated `veaf-config.lua`), so the terrain was *more* crowded than a
  normal mission, not less. Zero exhaustions is therefore a conservative reading.
- `no usable point in Disposition's cloud, walking the bearings instead` is emitted at **debug**
  ([`veafGrass.lua:439`](../../../src/scripts/veaf/veafGrass.lua)), so it is invisible in a normal
  `info`-level log. `T4-FORET` fell through to the bearing walk with no line saying why. Anyone
  re-running this needs `veafGrass.LogLevel = "debug"`, or that line has to move to info.
  **Done 2026-09-01 by `FIX-PLACEMENT-MOVES-ON-CLEAR-GROUND`: it logs at info, no debug level needed.**

**What `FIX-PLACEMENT-MOVES-ON-CLEAR-GROUND` changes for this ticket** (opened out of the `T1-DEGAGE`
finding below, delivered 2026-09-01): the exhaustion figure above still stands and does not need
re-running — the new guard only adds an earlier way to *accept* a bearing, so a case that did not exhaust
before cannot start exhausting now. What it does change is the `T1-DEGAGE` row: that escort should no
longer move at all, which is the half of this ticket's definition of done that was unprovable.

## What the measurement also revealed, and what it does to this ticket's non-regression

**`T1-DEGAGE` was the non-regression case: nothing should have moved. Something did** — the escort went
from bearing 0 to bearing 25 at 1.12x, on open ground with nothing within a kilometre.

Reading [`findClearBearing`](../../../src/scripts/veaf/veafGrass.lua) explains it: tier 1 consults the
scenery cloud **before** testing the requested bearing at all. It sorts the cloud's points by distance
to the wanted spot and takes the nearest one that passes — but the wanted spot itself is never a
candidate, so the escort moves *every time the cloud answers*, clear ground or not. Tier 2's comment
states the opposite intent — *"The original bearing first at every distance, so the group stays where it
was aimed when it can"* — and tier 1 short-circuits it.

This matters here because this ticket's definition of done says *"a FARP far from anything is never
refused and nothing moves"*. **That half is already untrue on `develop`**, independently of any refusal
this ticket adds, so it cannot be proven as written until the tier-1 behaviour is settled.

The fix is not to test the requested bearing first: `allClear` cannot see forests, so that would put
escorts back in the trees. The tenable route is the `gap` tier 1 already computes — if the closest cloud
candidate is within `PLACEMENT_CLEARANCE` of the wanted spot, keep the wanted spot. ~~**Not decided, and
not in scope here**~~ — David's call the same day: **a lot of its own**,
[`FIX-PLACEMENT-MOVES-ON-CLEAR-GROUND`](../../FIX-PLACEMENT-MOVES-ON-CLEAR-GROUND/PRD.md), which
implemented exactly that route on 2026-09-01 and is waiting on its own in-game proof.

## The threshold question ticket 03 must answer first

Ticket 03 adds the scenery criterion, which makes the search **harder** to satisfy and therefore makes
this refusal fire more often. Land 03, measure how often nothing is clear at any bearing or distance on
real terrain, and only then choose whether the refusal fires on the first exhaustion or after a widened
search.

If 03's measurement shows the search exhausts often, this ticket is a mission-breaker rather than a fix,
and it goes back to David with the number rather than shipping.

## What was built, 2026-09-30 — and the one departure from the design above

**The refusal is not a parameter of `buildFarpUnits`.** The second design point settled it: `spawnFarp`
creates the FARP **static** before it calls `buildFarpUnits`, so a refusal decided inside would leave
the platform standing — a half-built refused FARP, the outcome the point warned against. So the
question moved in front of everything: `veafGrass.canPlaceFarpEscort(farp)` lays the escort out exactly
as `buildFarpUnits` does (`veafGrass.farpEscortLayout`, extracted for that) and reports whether the
search found a bearing; `spawnFarp` asks it before `veaf.addStatic` and returns `nil` with the message.
Ruling 3 holds by the same construction the design relied on: `buildFarpsUnits`, the editor's path,
never asks.

`findClearBearing` now returns `angle, scale, found`; the fallback angle is unchanged, so tents, props
and windsock need no change. `buildFarpUnits` searches again once the tents and props stand, so the
escort avoids them too. If that second search exhausts — the tents having taken the only clear
bearing — the escort keeps the placement the `-farp` was accepted on, which `canPlaceFarpEscort` hands
over, rather than falling back to the requested bearing in silence (found by the pre-PR review).

## Definition of done

- [x] `findClearBearing` can report *"nothing clear"* distinguishably from a bearing, and refuses nothing
      itself
- [x] Only the escort caller turns that into a refusal; tents, props and the windsock keep today's
      fallback
- [x] **Only the `-farp` path refuses** — asked in `spawnFarp` before anything exists rather than as a
      `buildFarpUnits` parameter (see above); the editor's static FARPs never ask
- [x] A refused FARP creates **nothing** — the test counts the statics: 0, platform included
- [x] The message is translated in both locales, names the FARP and gives the reason
- [x] 03's exhaustion measurement is recorded here and the threshold justified by it — 0/4, so the
      refusal fires on the first exhaustion
- [x] Lua tests: a placeable escort still places, an unplaceable one on the **`-farp` path** refuses with
      the message and creates nothing, a silent one refuses without a message, and an unplaceable
      **windsock** or set of props never refuses anything. The startup path is pinned by a test calling
      `buildFarpUnits` with nowhere to go: it never asks `canPlaceFarpEscort`, and builds the escort on
      the requested bearing
- [ ] Non-regression proven as in 6.15.33: a FARP far from anything is never refused and nothing moves —
      in the unit tests yes; **in game, R19**. The "nothing moves" half is what
      `FIX-PLACEMENT-MOVES-ON-CLEAR-GROUND` ticket 03 settles, on the same branch
- [x] `CHANGELOG.md` entry under `[Unreleased]` calling this out as a behaviour change
- [x] `stylua --check` clean; `luacheck` runs in the CI Lua gate
