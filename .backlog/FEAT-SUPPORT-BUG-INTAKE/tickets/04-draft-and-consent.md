# 04 — The preview, and the click that files it

Status: ✅ done

Type: feat

## What to build

The service shows the issue exactly as it will be filed, and waits for the user to click.

The preview is entirely **facts**: what he typed in the form, the `doctor` block, the redacted log
excerpt, the located `file:line` with its neighbourhood, the mission summary, and what the prior-art
sweep checked. No hypothesis appears here — the enrichment of
[ticket 08](08-ai-enrichment.md) runs *after* the issue exists, and lands on it as a labelled
addition.

That ordering is the point: a quota that has run out, or a reporter without the role, can never cost
a report. The issue is filed either way.

## Why the user clicks

The issue is filed by a machine account, so the text carries his report without carrying his name —
he should see what is written on his behalf. And most of the preview is material he never wrote: the
log excerpt, the extracted code, the environment. He typed three fields; twenty lines get published.
The click is where he can see the difference and say *not that*.

What it does **not** do is filter noise: someone reporting a non-bug in good faith will click just
as readily. That is accepted; the prior-art sweep and the labelled hypothesis are what keep the
tracker honest, not the consent step.

## Mechanics

- The draft is rendered in the thread, within Discord's message limits, with the long parts folded
  or truncated **visibly** — never silently cut.
- File, edit and cancel. Edit reopens the modal with his answers in place and regenerates the
  preview.
- A draft nobody acts on expires, and says so when it does. An abandoned draft must not turn into an
  issue days later.
- The escalation button on `/ask` lands on the modal of [ticket 01](01-form-and-extraction.md),
  pre-filled with the question and the unsatisfying answer; the preview then behaves as usual.

## Definition of done

- [x] Preview rendered in the thread, carrying facts only
- [x] File / edit / cancel, with edit reopening the modal and regenerating the preview
- [x] Truncation always visible; nothing silently dropped
- [x] Preview expiry, announced
- [x] `/ask` escalation carries question and unsatisfying answer into the modal
- [x] Unit tests: each control, expiry, an over-long draft, the escalation path
- [x] Quality gate clean

## What was built

`veaf_support_bot/draft.py` holds the draft and the two bounds; the buttons live in
`discord_bot.py`, and the intake never draws one.

**The preview is the issue, not a rendering of it.** `IssueFiler.draft_of` calls the same
`render_body` the filing path calls, with the same arguments, so a preview that drifts from what
gets published is a test failure rather than a surprise on a public tracker. The one thing a second
renderer could never prove is that the issue says what the preview said.

**The question moved onto the exchange.** `decide` and `confirm` are now part of `BugExchange`
rather than objects built at start-up, because the buttons hang off *this* reporter's own message —
there is no reporter to ask when the service boots. That is also what finally answers ticket 03's
open point: `PriorArtGate.run` takes the confirmation as an argument, the gate's own field is gone,
and the proposal is genuinely put to the reporter with its evidence instead of always answering
*rejected*.

**Two things publish, and both wait for the click.** The ticket names the issue; the flow also
writes a *comment* when the reporter accepts a duplicate, carrying the same material onto the same
public tracker. Recognising an issue as his is not the same act as agreeing to publish twenty lines
under it, so the comment is previewed and confirmed exactly like the issue, under its own heading.

**Every failure leans the same way.** A silence expires, a Discord error cancels, an answer nobody
wrote a case for is treated as a refusal — the only path that reaches GitHub is a press of *File the
issue*. The two waits are five and eight minutes against Discord's fifteen-minute interaction token,
so the expiry can still be announced on the message it happened to; a timeout the service could no
longer write to would leave the reporter on a preview that never resolves.

**Truncation states its counts.** `fold` cuts on a line boundary, closes a fenced block it ran
through, and returns what it dropped so the notice can name it — the long parts are exactly the ones
the reporter did not write, so a silent cut would misrepresent the part that matters most.

## What ticket 06 still has to pick up

The escalation button carries the `/ask` exchange into the form but **not** the thread it came from:
`BugSubmission.thread_url` is still empty, so the issue says the thread was not recorded. Ticket 06
owns that link, and it is the same link the relay needs.
