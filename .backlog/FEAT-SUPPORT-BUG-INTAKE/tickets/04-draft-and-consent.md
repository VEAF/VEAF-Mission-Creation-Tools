# 04 — The draft, and the click that publishes it

Status: ⬜ ready

Type: feat

## What to build

The service shows the issue exactly as it will be filed, and waits for the user to publish it.

The draft has two clearly separated parts:

1. **The facts** — what the user described, the `doctor` block, the redacted excerpt, the mission
   summary, what the prior-art sweep checked.
2. **A labelled automatic hypothesis** — the suspected file and line, and why. Marked as a machine
   guess, visually, per block. Not a footnote disclaimer: those are not read.

## Why the user clicks

Two reasons, and only the first is about spam. The issue is filed by a machine account, so the text
carries his report without carrying his name — he should see what is written on his behalf. And the
click is the moment he can say *that is not what I meant*.

What it does **not** do is filter noise: someone reporting a non-bug in good faith will click just
as readily. That is accepted; the prior-art sweep and the labelled hypothesis are what keep the
tracker honest, not the consent step.

## Mechanics

- The draft is rendered in the thread, within Discord's message limits, with the long parts folded
  or truncated **visibly** — never silently cut.
- Publish, edit and cancel. Edit means the user amends his description and the draft is regenerated;
  it does not mean he hand-edits the machine's hypothesis.
- A draft nobody acts on expires, and says so when it does. An abandoned draft must not turn into an
  issue days later.
- The escalation button on `/ask` lands here, carrying the question and the answer that did not
  satisfy — that context is part of the report.

## Definition of done

- [ ] Draft rendered in the thread, facts and hypothesis visually separated
- [ ] Hypothesis labelled as a machine guess at the block level
- [ ] Publish / edit / cancel, with edit regenerating from an amended description
- [ ] Truncation always visible; nothing silently dropped
- [ ] Draft expiry, announced
- [ ] `/ask` escalation carries question and unsatisfying answer into the draft
- [ ] Unit tests: each control, expiry, an over-long draft, the escalation path
- [ ] Quality gate clean
