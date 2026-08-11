# 01 — Triage the 126 verbs by mission-maker intent

Status: ✅ done
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

- [x] Enumerate the 126 verbs from their `docs/cli/` (read-only; the code is GPL, the page titles
      are a checklist).
- [x] For each, write the mission-maker sentence or mark it rejected with why.
- [x] Group the survivors into actions. **One action per intent, not per verb** — "move that group
      5 km east" is one action taking a bearing and a distance, not `group set-x` + `group set-y`.
- [x] Check each survivor against what already exists: `list_catalog` on the current build, not
      memory. Some may be reachable by composing existing actions.
- [x] Flag the ones that need a **read** action to be usable at all. Mutating a unit's loadout
      presupposes being able to see the current one; `describe_mission` may or may not already
      expose it.
- [x] Note the ones that are **cheap because the parity layer already reaches them** versus the ones
      needing new `.miz` surgery — the difference decides ticket order.

## Output

A section appended to this lot's PRD: the surviving actions, grouped, each with its
mission-maker sentence and its cost class. Then one ticket file per group for anything beyond
02–04, and the gated line in the Scope table replaced by real rows.

## Notes

If the triage concludes that a family is not worth it, say so in the PRD and delete its row.
A recorded "we looked and decided no" is worth as much as an implementation — it is what stops
the next person re-reading 126 pages.

## Delivered — 2026-08-11

The triage itself is in [the PRD](../PRD.md), where tickets 05+ can be written from it. What follows is
what the method produced and what surprised it.

**Enumerated, not sampled.** The 126 page names came from the GitHub contents API on
`nielsvaes/dcs-sms/docs/cli`, and a script asserted that every one of them carries **exactly one**
verdict — no duplicates, none missed — before a word of the triage was written. That guard exists
because a hand-picked subset already cost this repository a false "the whole family is fixed" claim.

Verdicts: **65 keep, 22 reject, 18 read-first, 17 low value, 4 already have.** Their README's 141 pages
are these 126 plus 15 host commands (`setup`, `install-hook`, `tail-log`, …), which are not mission edits.

### The finding that reorders the lot

The ticket said to flag what needs a read action to be usable, and guessed `describe_mission` "may or may
not already expose it". Measured: **it does not expose units at all.** Groups (name, coalition, country,
category) and zones (name, x, y, radius) — that is the entire surface. No loadout, no skill, no livery,
no route, no waypoint, no task.

So tickets 02 and 04 are not *nicer* with a read action, they are **blind without one**, and it goes
first as ticket 05. It also answers 18 of the 126 verbs by itself, which no setter approaches.

### Three families rejected, and the one worth arguing with

`file`/`camera`/`group-focus` (7) manipulate an **open editor session**, which ADR 0017 declined on
measurements — the concept does not exist on our side. `resources-get/set` (2) are build-owned; an agent
editing `mapResource` by hand re-creates two bugs we have already paid for.

The contestable one is **arbitrary triggers (13)**, rejected as a family: VEAF *replaces* triggers rather
than authoring them, and the single trigger we generate exists to load the scripts that make the rest
unnecessary. Their `list-predicates`/`describe-predicate` design is genuinely good — descriptor-driven,
so it cannot rot when ED adds a predicate — but it is only worth having if we author triggers. **Flagged
for David to break**: it is the one verdict here that is a judgement about VEAF's shape rather than a
measurement.

### The exploration note was wrong on three counts

Worth recording because this lot was scoped from that note: zones are **11** verbs and not 8, F10
drawings **19** and not 11, route + waypoint **27** and not 25. The conclusion holds; the surface is
wider than advertised. This is what enumerating buys over trusting a summary.

### Output

Three new tickets — [05 read](05-describe-units.md), [06 zones](06-zone-editing.md),
[07 drawings](07-map-drawings.md) — the gated row in the scope table replaced by real ones, and the
execution order set to **05 → 02 → 03 → 04 → 06 → 07**, which is not the numbering.

No code, so no version bump and no CHANGELOG entry: this ticket's whole product is the decision and the
tickets that follow from it.
