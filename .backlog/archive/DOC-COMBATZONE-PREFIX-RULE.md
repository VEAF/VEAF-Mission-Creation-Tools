# DOC-COMBATZONE-PREFIX-RULE — the rule that decides what a zone contains is written nowhere

Status: ✅ done · archived 2026-09-28

Origin: found while writing the tutorial (`DOC-TUTORIAL`, PR #863). Verified on `develop`.

## The rule

A combat zone only picks up a group whose name **starts with the zone's name**
(`veafCombatZone.lua:1974`):

```lua
if string.sub(groupName:upper(), 1, string.len(upperTriggerzoneName)) == upperTriggerzoneName then
```

Case-insensitive, prefix only. A group sitting inside the trigger zone but named otherwise is
simply never seen.

## Why it matters

It is the single rule that decides what a zone contains, and **neither combat-zone page states it**
— `grep -i 'commence par\|starts with'` over `veafCombatZone.md` and `.en.md` returns nothing.

The pages then show examples that do not name their zone: `ALPHA-MANPAD-1 #spawnchance=50`, and
`SPAWN-SA11 #command="-spawn sa-11, side red"` under a separate heading. Nothing there is provably
wrong — `ALPHA-MANPAD-1` works in a zone called `ALPHA` — but a reader has no way to know the name
is load-bearing, and `SPAWN-SA11` reads like a name chosen freely. That is exactly the mistake a
newcomer makes once and cannot debug: the zone activates, and nothing happens, with nothing in the
log to explain it.

(An earlier report claimed the pages pair these examples with a `ZONE-ALPHA` zone. They do not —
that name appears nowhere. The gap is the unstated rule, not a contradicted example.)

## Also in this lot

`DOC-TUTORIAL` shipped "target behaviour" call-outs on `#spawnchance` and dynamic-slot stock,
because both lots were still in flight when it was written. **Both have landed** (#859 and #860),
so the call-outs describe the present now and should be unflagged.

## Definition of done

- [ ] The prefix rule is stated where a mission maker meets combat zones — in both languages, and
      as a rule rather than a footnote
- [ ] Every example on those pages either names its zone or is written so the prefix is visibly
      the zone's name
- [ ] The tutorial's target-behaviour call-outs become plain statements
- [ ] `poetry run docs-check` passes

## Scope

| # | Ticket | Type |
|---|--------|------|
| 01 | [State the prefix rule, and unflag the tutorial](DOC-COMBATZONE-PREFIX-RULE.md) | docs |

## Worth raising, not fixing here

The rule is silent at runtime: a group in the zone with the wrong name produces no warning. Whether
the script should say something — at least in the log, at zone build-up — is a product question,
and a real one, since this failure is undebuggable from the game. Left to David.

---

## Tickets, in full

## 01 — State the prefix rule, and unflag the tutorial

Status: ✅ done

Type: docs · Files: `doc/mission-maker/scripts/veafCombatZone.md` + `.en.md`,
`doc/mission-maker/concepts/` and `TUTORIAL.md` (both languages)

### What to write

The rule, plainly, where someone meets combat zones for the first time: **a group is part of a zone
only if its name starts with the zone's name** (case-insensitive). Being inside the trigger zone is
not enough.

Make it concrete — a zone named `CZ-Alpha`, groups `CZ-Alpha-ARMOR`, `CZ-Alpha-AAA`, and a
counter-example named `ARMOR-1` that is silently ignored. The counter-example is the useful half:
it is the mistake a newcomer makes, and it produces no error anywhere.

Then check every existing example on those pages: each must either name its zone or be written so
its prefix is visibly the zone name. `SPAWN-SA11` under the `#command` heading is the one most
likely to mislead.

### Unflag the tutorial

`DOC-TUTORIAL` wrote "target behaviour" call-outs for `#spawnchance` and dynamic-slot stock while
those lots were in flight. Both have landed — #859 (the probability is honoured; the forced draw
survives only under an explicit `#spawncount`) and #860 (stock is filtered to what the terrain can
park). Turn the call-outs into plain present-tense statements and drop the flags.

### Definition of done

- [ ] The rule appears on both combat-zone pages, both languages, with the counter-example
- [ ] The tutorial and the concept card for combat zones state it too, since that is where a
      beginner lands
- [ ] Every example on those pages is consistent with the rule
- [ ] No "target behaviour" flag remains for the two landed lots
- [ ] `poetry run docs-check` passes

---
