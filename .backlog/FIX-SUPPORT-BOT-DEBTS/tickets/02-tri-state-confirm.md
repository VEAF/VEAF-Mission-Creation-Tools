# 02 — *He said no* and *he said nothing* are not the same answer

Status: ⬜ ready

Type: fix

## What is wrong

`ThreadExchange.confirm` returns a **boolean**, and three states arrive as `False`:

| What happened | What the code knows |
|---|---|
| He clicked *No, mine is different* | `False` |
| He clicked nothing for 300 seconds | `False` |
| Discord refused to display the question | `False` |

The safe direction is right — an unanswered guess must never silence a report — but the *record* is
not: the issue body cannot say which of the three occurred. Lot 5 got as far as it could without
touching the protocol: the sentence no longer claims he disagreed, it says the request was
maintained, which is true in all three. A tri-state would let it say which.

## Why it was left out of lot 5

It touches code both flows sit on: the protocol in `exchange.py`, the gate in `priorart.py`, the
adapters in `intake.py` and `suggest.py`, and the view in `discord_bot.py`. Smuggling that into a
lot about `/suggest` would have made its diff unreviewable — and lot 5's diff was already over the
review limit and had to be split.

## What to build

A returned state rather than a boolean — `SAME`, `DIFFERENT`, `UNANSWERED` — with `UNANSWERED`
covering both the silence and the failure to display, since neither is an opinion.

Every caller has to be **read**, not adapted mechanically: what matters is that no path turns
`UNANSWERED` into agreement. The bug flow's duplicate comment is the sharp edge — it publishes on an
existing issue, and it must keep requiring an explicit *yes*.

## Definition of done

- [ ] Three states, and `UNANSWERED` produced both by a timeout and by a refused display
- [ ] Nothing treats `UNANSWERED` as agreement — asserted per caller
- [ ] The issue body distinguishes the three in its prior-art section, both languages
- [ ] Unit tests: one per state, per flow
- [ ] Quality gate clean
