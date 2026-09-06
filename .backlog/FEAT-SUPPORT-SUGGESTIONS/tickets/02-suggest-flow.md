# 02 — `/suggest` files a feature request worth reading

Status: ✅ done

Type: feat

## What to build

The command itself, on top of what [ticket 01](01-prior-art-first.md) established and what the bug
lot already provides.

- `/suggest` opens a public thread, like `/ask` and `/bug`.
- The agent asks for what the template needs and the user rarely volunteers: **the problem behind
  the request**, not only the solution he imagined. `feature_request.yml` asks for problem,
  solution, alternatives and context — the first field is the one that makes a request decidable.
- The draft is shown, the user validates, the issue is filed under the same GitHub App with the
  `enhancement` label, in the user's language.
- The prior-art result is recorded in the issue: what was checked, and what was found. A reader
  three months later should not have to redo the search.

## What it stops short of

No design sketch. The session weighed it and turned it down: a wrong sketch in a public issue
steers the discussion into a wall, durably, and it is expensive to unwind. The agent states the
problem, the request and the prior art. Where it would fit and what it would touch is the work of
whoever opens the lot.

## Reuse, not reinvention

The form, the preview, the GitHub App, the relay and the quotas all come from
[`FEAT-SUPPORT-BUG-INTAKE`](../../FEAT-SUPPORT-BUG-INTAKE/PRD.md). If any of it has to be rewritten
here, that is a defect in the bug lot's factoring, not a task for this one.

## What reuse actually cost

Two pieces of the bug lot were written against `BugReport` and could not serve a second issue shape
without being copied — which the PRD names as a defect in that lot's factoring rather than work for
this one. Both were factored rather than duplicated:

- the **exchange protocol** every flow needs from Discord moved to `exchange.py` as `ThreadExchange`;
- the **filing mechanism** kept one implementation and gained `file_prepared`, the door an
  already-rendered issue comes through. One issue per key however many times it is asked, the
  recovery search when the ledger lost the answer, failures as outcomes — all of it shared. The
  assembly now builds **one** filer for both flows: the ledger is a whole-file rewrite, and two
  writers would lose each other's entries, which on a public tracker is a second issue.

`render_match` moved next to the `Sweep` it renders. 848 tests stayed green across the move.

## What the reviews found, and the one thing left open

Sourcery's weekly budget was spent when this lot was written, so it was reviewed by agents before
the PR was opened, then by Sourcery once the lot was split under the 150 000-character limit. Eleven
defects, all fixed here — among them three that would have shipped green:

- **three timed waits do not fit in one interaction token.** 300 + 300 + 480 against the 900 seconds
  a deferred token lives. Somebody could click *File the issue* on a dead token, having consented to
  something that never happens. The checks now give way, never the consent;
- **the no-filer path sent Discord 2040 characters**, measured, where it accepts 2000. The refusal is
  swallowed, so the asker kept an ephemeral placeholder for ever after filling five fields;
- **`/suggest` was published where it could never file anything.** Everything published goes through
  a redactor bound to the checkout, so without one nothing can be filed — and the command blamed a
  GitHub App that was correctly configured;
- **a suggestion could be told to update its version.** The flow reused the bug sweeper whole,
  closed issues included, so a feature request scoring against a recently closed issue was answered
  *this may already be fixed, update*;
- **two of my own tests were green for the wrong reason** — one sweep that matched nothing (the
  default *cancel* ended the flow), and one `assertIs(None, None)` guarding the very hazard the lot
  was designed around.

**Left open, deliberately: `ThreadExchange.confirm` is a boolean where three states exist.** *He
said no*, *he said nothing*, and *Discord refused to show him the question* all arrive as `False`.
The issue body no longer claims he disagreed — it says the request was maintained, which is true in
all three — but a tri-state would let it say which. It touches the bug flow too, so it is a lot of
its own rather than a change smuggled into this one.

## Definition of done

- [x] `/suggest` registered, answering in a public thread
- [x] The exchange elicits the underlying problem, not only the proposed solution
- [x] Draft, consent and publication reusing the bug lot's components unchanged
- [x] Issue filed with `enhancement`, in the template's shape, in the user's language
- [x] Prior-art findings recorded in the issue body
- [x] No design sketch produced
- [x] Unit tests: full flow, a suggestion resolved by prior art, a rejected match continuing
- [x] Quality gate clean
