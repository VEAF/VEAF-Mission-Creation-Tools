# FEAT-COMBAT-EFFECTIVE-ADOPTION — adopt the combat-effectiveness predicate beyond the report

Status: ✅ done — shipped in 6.15.29

Follow-up to [`FEAT-GROUP-COMBAT-INEFFECTIVE`](../FEAT-GROUP-COMBAT-INEFFECTIVE/PRD.md), which shipped
`veaf.isGroupCombatEffective` in 6.15.24 and deliberately adopted it in **one** place — the F10 zone
report, because that changes no mission behaviour. The analysis of the other two callers lives in that
PRD; this lot acts on it.

**Half of it is already answered: `completionCheck` is refused** (see below), so what remains is the
Skynet half alone.

## Skynet first, because it is safe

`veafSkynet.findSkynetElementToDefend` (`veafSkynetIadsHelper.lua:404`) picks which site a point-defence
group protects. With the predicate it would skip sites that can no longer fight, so a Tor does not spend
a mission guarding a decapitated S-300 while a live one goes undefended.

Invisible to a player until it matters, and it cannot end a mission early. Ship this half on its own.

## `completionCheck` — asked and refused, 2026-08-22

Put to David with the case that decides it: a player kills an S-300's tracking radar and leaves, leaving
four intact launchers, a search radar and three trucks alive and visible.

> **"non, tout doit être détruit"**

So `completionCheck` keeps counting living hostile units, and a zone completes only when there is nothing
left. Not a deferral and not a per-zone switch — the answer is no, and the guess this PRD carried (a
switch defaulting to today) is **withdrawn** rather than left looking like a plan.

That also settles what the predicate is *for*: telling a player what can no longer fight, not deciding
when his work is done. Clearing a zone means clearing it.

## What is left: Skynet, and it needs no arbitration

`veafSkynet.findSkynetElementToDefend` (`veafSkynetIadsHelper.lua:404`) picks which site a point-defence
group protects. With the predicate it would skip sites that can no longer fight, so a Tor does not spend
a mission guarding a decapitated S-300 while a live one goes undefended.

Invisible to a player until it matters, and it cannot end a mission early — which is why it survives the
refusal above. This lot is now only that.

## What shipped

Three lines in `findClosestSkynetElementInList`: a site whose group can no longer fight is passed over
when a point defence looks for something to protect. So a Tor does not spend a mission guarding a
decapitated S-300 while a live site next door goes undefended.

## Early-warning radars are exempt, and that is the interesting part

The first version judged every candidate, EWRs included, resting on a measurement: no EWR in the
generated database carries `SAM SR`, `SAM TR` or `SAM LL` (1L13, 55G6, FPS-117 and its domed variant,
FuMG-401, FuSe-65), so the predicate never read one as a finished SAM site.

That measurement is true and was the wrong thing to lean on. **An EWR is defended because it *sees*, not
because it shoots** — asking "can this still fight" about a radar is a category error, and the code's own
comment has always said EWRs are always defencible. Two consequences followed from judging them anyway:

- a **mixed group** — a mission maker putting a 55G6 and a launcher in one group — carries `SAM LL` with
  no tracking radar, so it would have lost its defence **silently**, today, with no datamine update
  needed;
- the behaviour depended on no EWR type ever gaining a SAM attribute upstream, which is not a property
  anyone here controls.

So the predicate is applied to SAM sites only. Caught in review (Sourcery, PR #788), filed under
"nitpick" and worth more than that.

**The first version of the tests got it wrong the same way**: all six used `type = "ewr"`, so they
exercised precisely what must *not* be filtered, and would have passed on a rule scoped either way. Now
two of them pin the exemption, and removing it fails them.

## The measurement is still worth keeping

The same sweep confirmed the rule bites where it should: of the 52 units carrying any SAM attribute, 27
have `SAM TR` — the tracking radars and the self-contained vehicles (Tor, Pantsir, Tunguska, Gepard) — and
**11 launchers have none**, depending on a separate radar (`Hawk ln`, `Kub 2P25 ln`, `5p73 s-125 ln`, …).
A Hawk site that loses its `Hawk tr` keeps launchers and a search radar, and is correctly finished.

The same sweep confirmed the rule bites where it should: of the 52 units carrying any SAM attribute, 27
have `SAM TR` — the tracking radars and the self-contained vehicles (Tor, Pantsir, Tunguska, Gepard) — and
**11 launchers have none**, depending on a separate radar (`Hawk ln`, `Kub 2P25 ln`, `5p73 s-125 ln`, …).
A Hawk site that loses its `Hawk tr` keeps launchers and a search radar, and is correctly finished.

## Definition of done

- [x] The `completionCheck` question put to David, and his answer recorded here — **refused**: everything
      must be destroyed
- [x] Skynet skips ineffective **SAM sites** when choosing what to defend, with tests — seven, including a
      distant live site beating a close dead one, that an EWR is defended even when judged ineffective,
      and that the point defence itself is never judged
