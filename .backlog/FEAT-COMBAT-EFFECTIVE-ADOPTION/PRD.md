# FEAT-COMBAT-EFFECTIVE-ADOPTION — adopt the combat-effectiveness predicate beyond the report

Status: ⬜ ready

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

## Definition of done

- [x] The `completionCheck` question put to David, and his answer recorded here — **refused**: everything
      must be destroyed
- [ ] Skynet skips ineffective sites when choosing what to defend, with tests
