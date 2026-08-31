# DOC-COMBATZONE-PREFIX-RULE — the rule that decides what a zone contains is written nowhere

Status: ⬜ ready

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
| 01 | [State the prefix rule, and unflag the tutorial](tickets/01-state-the-prefix-rule.md) | docs |

## Worth raising, not fixing here

The rule is silent at runtime: a group in the zone with the wrong name produces no warning. Whether
the script should say something — at least in the log, at zone build-up — is a product question,
and a real one, since this failure is undebuggable from the game. Left to David.
