# 01 — Triage the 126 verbs by mission-maker intent

Status: ⬜ ready
Type: chore
Files: this lot's PRD, then new ticket files for whatever survives

## Why this is first

The temptation is to open `dcs-sms`'s `docs/cli/` and start implementing. 126 actions would drown
the domain composites that are VMCT's actual advantage — an agent facing 155 actions picks worse
than one facing 40 — and most of those verbs answer questions no VEAF mission maker asks.

So this ticket produces **a list, with reasons**, and tickets 05+ are written from it. Tickets 02–04
are already scoped because the exploration note names their use case outright.

## Method

For each of the six families, and each verb inside it, answer one question: **what would a mission
maker ask an agent, in a sentence, that needs this?** A verb with no such sentence does not ship.

- [ ] Enumerate the 126 verbs from their `docs/cli/` (read-only; the code is GPL, the page titles
      are a checklist).
- [ ] For each, write the mission-maker sentence or mark it rejected with why.
- [ ] Group the survivors into actions. **One action per intent, not per verb** — "move that group
      5 km east" is one action taking a bearing and a distance, not `group set-x` + `group set-y`.
- [ ] Check each survivor against what already exists: `list_catalog` on the current build, not
      memory. Some may be reachable by composing existing actions.
- [ ] Flag the ones that need a **read** action to be usable at all. Mutating a unit's loadout
      presupposes being able to see the current one; `describe_mission` may or may not already
      expose it.
- [ ] Note the ones that are **cheap because the parity layer already reaches them** versus the ones
      needing new `.miz` surgery — the difference decides ticket order.

## Output

A section appended to this lot's PRD: the surviving actions, grouped, each with its
mission-maker sentence and its cost class. Then one ticket file per group for anything beyond
02–04, and the gated line in the Scope table replaced by real rows.

## Notes

If the triage concludes that a family is not worth it, say so in the PRD and delete its row.
A recorded "we looked and decided no" is worth as much as an implementation — it is what stops
the next person re-reading 126 pages.
