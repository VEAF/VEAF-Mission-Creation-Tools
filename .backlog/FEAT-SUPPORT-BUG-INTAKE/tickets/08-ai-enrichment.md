# 08 — One call, for members, while the quota lasts

Status: ⬜ ready

Type: feat

## What to build

The issue is already filed by the time this runs ([ticket 04](04-draft-and-consent.md)). This adds
**one** model call that reads the prepared context and returns a hypothesis, which is posted as a
clearly labelled comment or section on that issue.

Three gates, all cheap, all checked before the call:

1. **A VEAF role**, read from the Discord interaction itself. It cannot be forged and costs nothing.
2. **The daily ceiling**: 15 enrichments, against a measured free tier of 20 requests per day.
3. **One call per report**, enforced by the runtime rather than requested of the model.

## Why one call is enough

Everything an agent would have gone looking for is already in hand: the location, the surrounding
code, the callers, the catalogue matches, the prior art, the mission summary. The model is asked to
**conclude on a prepared file**, not to investigate. That is what turns ten to twenty calls into
one, and it is the whole reason the free tier is workable.

If one call proves insufficient, the answer is a better prepared context — more callers, a wider
neighbourhood, the matching rule's wording — not a second call.

## Failing without failing

Not a member, ceiling reached, model unavailable, malformed answer: in every case the issue stands
as filed and **says the hypothesis is absent**, with the reason in one plain sentence. The reporter
is never told his report failed, because it did not.

## The hypothesis, and how it is presented

Labelled as a machine guess, at block level — not a disclaimer at the bottom, which nobody reads.
It carries the suspected file and line and why. It is never phrased as a diagnosis, and it must be
possible for a maintainer three months later to tell in one glance what was measured from what was
guessed.

## Notes

- The daily counter shares its implementation with
  [`FEAT-SUPPORT-DISCORD-QA` ticket 03](../../FEAT-SUPPORT-DISCORD-QA/tickets/03-per-user-quota.md),
  with a much lower ceiling. Fail closed: a counter that cannot be read means no enrichment, never
  unlimited enrichment.
- Consumption is recorded per report so the ceiling can be revisited from figures.
- Which role gates this is open question 1 of the PRD; the code reads a role id from the environment
  rather than a name.

## Definition of done

- [ ] One model call per report, enforced by the runtime
- [ ] Role check from the interaction, ceiling check, both before the call
- [ ] Hypothesis posted labelled, with file and line, visually separable from the facts
- [ ] Every refusal path leaves the issue intact and states why the hypothesis is missing
- [ ] Counter fails closed
- [ ] Consumption recorded
- [ ] Unit tests with the model mocked: enriched, non-member, ceiling reached, model unavailable,
      malformed answer
- [ ] Quality gate clean
