# 08 — One call, for members, while the quota lasts

Status: ✅ done

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

- [x] One model call per report, enforced by the runtime
- [x] Role check from the interaction, ceiling check, both before the call
- [x] Hypothesis posted labelled, with file and line, visually separable from the facts
- [x] Every refusal path leaves the issue intact and states why the hypothesis is missing
- [x] Counter fails closed
- [x] Consumption recorded
- [x] Unit tests with the model mocked: enriched, non-member, ceiling reached, model unavailable,
      malformed answer
- [x] Quality gate clean

## What was built

`veaf_support_bot/enrichment.py` holds the three gates and the single call;
`worker.HypothesisClient` makes it; `issue_body.render_hypothesis` labels it.

**The prepared file is the issue body itself.** Nothing new had to be assembled: the location, the
surrounding code, the callers, the catalogue matches, the prior art and the mission's shape are
already in it, in that order. That is what turns ten calls into one — the model is handed a finished
file and asked to conclude on it.

**The prompt lives in the Worker, not here.** `kind: "bug"` on the existing `/analyze` route selects
`bugHypothesisInstruction`, next to the log-analysis one. What a machine is allowed to claim on a
public tracker is then written down in a single place, and adding a caller does not add a dialect of
it. The route needed no new permission: the `discord` client mode already reaches `/analyze`.
**Consequence: the Worker is deployed by hand, so the instruction is live only once
`npx wrangler deploy` has run.**

**The role is read from `Member._roles`, not from `Member.roles`.** The public property resolves
each id against the guild cache and silently drops what it cannot find — and this bot runs on
`Intents.none()`, so that cache can be empty. Reading the property alone would have refused every
reporter forever while looking perfectly healthy. `tests/test_discord_consent.py` asserts the raw
payload path, because that is the failure this repository has shipped green before.

**An unset role switches the feature off, and that is the default.** Not a degraded mode: reports
are filed complete, with no hypothesis section at all, and both the issue and the reporter are told
which of the five reasons applies. Open question 1 of the PRD therefore needs no answer before
shipping — it needs one before the feature does anything, and it is one environment variable.

**The allowance fails closed**, unlike `/ask`'s. There, silence looks like a broken bot; here it
costs one paragraph on an issue that is already filed, and the resource is shared with the
documentation site and the command line.

## Still open

`SUPPORT_BOT_ENRICH_ROLE_ID` is unset, so nothing is enriched yet — David's call on which role, and
where the service reads its environment.
