# 04 — The preview, and the click that files it

Status: ⬜ ready

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

- [ ] Preview rendered in the thread, carrying facts only
- [ ] File / edit / cancel, with edit reopening the modal and regenerating the preview
- [ ] Truncation always visible; nothing silently dropped
- [ ] Preview expiry, announced
- [ ] `/ask` escalation carries question and unsatisfying answer into the modal
- [ ] Unit tests: each control, expiry, an over-long draft, the escalation path
- [ ] Quality gate clean
