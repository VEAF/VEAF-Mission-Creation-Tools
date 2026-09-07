# 04 — A proposal from the model shows what it is proposing

Status: ✅ done

Type: fix

## What happened, in front of a human

David, 2026-09-07, minutes after ticket 05 of the previous lot shipped. He asked `/suggest` for a UI
in `veaf-tools` resembling the one in ctld-tools, and the bot answered:

> 🔎 **Ta demande ressemble à un ticket déjà ouvert : #938.**

**#938 is his own bug report**, filed five minutes earlier — title *La mission ne fonctionne pas*,
labels `bug`, `filed-by-bot`, `lua`. Nothing to do with a UI.

Two defects, and the second explains the first.

## 1. The proposal carries no evidence

The whole service runs on one rule: **a match is proposed with its evidence, never asserted.** The
deterministic sweep prints the reference, the score and the shared words, precisely because a wrong
"this is a duplicate" silences a real request and the asker will not insist.

The proposal built from the model prints a number. Had the title been on screen — *La mission ne
fonctionne pas* — the answer would have been obvious without opening GitHub.

## 2. Bug reports are offered as candidates

Every open issue travels with the request, bug reports included. A feature request cannot be a
duplicate of a bug report: they are different natures, and the tracker says which is which with the
`bug` label the service itself applies.

Note what is **not** filtered: issues the bot filed. A duplicate may perfectly well be a ticket this
service opened for somebody else; what is filtered is the nature, not the origin.

## What to build

- the proposal shows the issue's **title and URL**, both already in hand — the sweep reads them from
  the same source;
- issues labelled `bug` are not offered to the model at all, which also shortens the prompt;
- the match handed to the rest of the flow carries that title, so the *second voice* comment and the
  log line name the issue rather than a bare number.

## Done when

- a proposal shows title and link, and refusing it still carries the request on;
- a bug report is never proposed as a duplicate of a suggestion;
- tests: the prompt holds no bug report, and the proposal holds the title of what it names.
