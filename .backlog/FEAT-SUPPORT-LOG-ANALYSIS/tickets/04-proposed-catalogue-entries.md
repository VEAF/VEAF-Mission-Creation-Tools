# 04 — Unknown recurring patterns come back as proposed rules

Status: ⬜ ready

Type: feat

## The idea

David's constraint on this flow was explicit: it must **not** create issues. That leaves a question
— if nothing is captured, the analyser never gets better, and every user pays for the same
"pattern not catalogued" answer.

The answer is to capitalise on the catalogue rather than on the tracker. A pattern that shows up
repeatedly and matches nothing in `rules.json` is a **missing catalogue entry**, and a proposed
entry is worth more than an issue: once merged, the next user gets a verified explanation with no
model call, offline, for free.

## What to build

- Recognise, inside one analysis, patterns that recur and match no rule — normalised so that
  addresses, identifiers and timestamps do not make two occurrences of the same message look
  different.
- Produce a **candidate entry** in `rules.json` shape: `id`, `label`, `help`, `match`, whether it is
  noise, which family it belongs to.
- Never apply it silently. A proposed rule is a proposal; the catalogue stays hand-curated, which
  is precisely what makes it trustworthy.

## Open question — the delivery channel

Undecided, and it is David's call (open question 2 of the PRD):

| Route | What it costs |
|---|---|
| Automatic PR on the repository | traceable and reviewable; needs a credential in a desktop tool, which is a hard no as written |
| A local file the user can send | zero infrastructure; depends on someone bothering |
| A message to a Discord channel | fits the programme, but only exists from lot 3 onwards |

The detection and the candidate-entry generation ship here regardless; the transport is wired once
the route is chosen.

## Definition of done

- [ ] Recurrence detection over normalised messages, unit-tested on a fixture where the same error
      appears with varying identifiers
- [ ] Candidate entries generated in `rules.json` shape, with a valid `match` regex
- [ ] Generated regexes validated before being offered — an unanchored or catastrophic pattern is
      rejected rather than proposed
- [ ] Nothing is written to `rules.json` automatically
- [ ] The chosen delivery route implemented, or explicitly recorded as deferred with the reason
- [ ] `poetry run pytest`, ruff check + format, mypy clean
