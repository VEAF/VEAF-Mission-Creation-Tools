# 04 — Refuse the FARP when the escort cannot be placed

Status: ⬜ ready — **land ticket 03 first and measure**
Type: fix

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

## The threshold question ticket 03 must answer first

Ticket 03 adds the scenery criterion, which makes the search **harder** to satisfy and therefore makes
this refusal fire more often. Land 03, measure how often nothing is clear at any bearing or distance on
real terrain, and only then choose whether the refusal fires on the first exhaustion or after a widened
search.

If 03's measurement shows the search exhausts often, this ticket is a mission-breaker rather than a fix,
and it goes back to David with the number rather than shipping.

## Definition of done

- [ ] `findClearBearing` can report *"nothing clear"* distinguishably from a bearing, and refuses nothing
      itself
- [ ] Only the escort caller turns that into a refusal; tents, props and the windsock keep today's
      fallback
- [ ] **Only the `-farp` path refuses.** `veafGrass.buildFarpUnits` takes the refusal as a parameter;
      `veafSpawnGround.lua:105` passes it, `veafGrass.lua:586` does not
- [ ] A refused FARP creates **nothing** — verified, not assumed
- [ ] The message is translated in both locales, names the FARP and gives the reason
- [ ] 03's exhaustion measurement is recorded here and the threshold justified by it
- [ ] Lua tests: a placeable escort still places, an unplaceable one on the **`-farp` path** refuses with
      the message and creates nothing, an unplaceable one on the **startup path** builds anyway with
      today's fallback, and an unplaceable **windsock** never refuses anything
- [ ] Non-regression proven as in 6.15.33: a FARP far from anything is never refused and nothing moves
- [ ] `CHANGELOG.md` entry under `[Unreleased]` calling this out as a behaviour change
- [ ] `stylua --check` and `luacheck` clean
