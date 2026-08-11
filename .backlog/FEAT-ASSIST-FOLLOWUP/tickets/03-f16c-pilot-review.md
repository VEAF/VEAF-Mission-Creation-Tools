# 03 — A pilot review of the F-16C slice

Status: 🧑 waiting-human
Type: docs

## What is being asked

The F-16C cold-start checklist shipped as **six steps**, written by whoever built the engine — not by
an F-16C pilot. The parent lot flew it and confirmed the *engine* works. It never confirmed the
*content* is the right content.

Four of the six steps are **pilot-confirmed** rather than automatic, and for a measured reason: a
spring-loaded switch is already back at neutral and a button has no position, so neither can be read
from a mission. That is a mechanism limit, not a content choice — worth stating up front so a
reviewer does not spend their time on it.

## The question for the reviewer

Not "does it work" but:

- Is the **order** right, and is anything missing that a real cold start needs?
- Are the six the right slice — a coherent thing to be guided through — or an arbitrary cut?
- Do the labels say what a pilot would say?
- Are the four confirm-only steps the ones a pilot would *expect* to confirm, given they cannot be
  detected?

## Why it matters more than it looks

Cold start is the engine's **first client**, and it is what anyone evaluating the feature will try.
A checklist that guides you through the wrong six things discredits a working engine.

## Tasks

- [ ] Get an F-16C pilot through the checklist in game.
- [ ] Record their answers to the four questions above, verbatim where it matters.
- [ ] Fold accepted changes into `checklists/f16c-cold-start.yaml` — steps and labels only; a change
      that needs a new **check kind** is a different ticket and should be split out.
- [ ] If the reviewer says the slice itself is wrong, say so plainly here rather than quietly
      reshaping it: that is a finding about the first client, and the roadmap should hear it.

## Acceptance criteria

- [ ] A named reviewer has flown it and their verdict is written down.
- [ ] Either the YAML is updated, or the ticket records that it was reviewed and left as-is.

## Blocked on

David: an F-16C pilot, possibly himself.
