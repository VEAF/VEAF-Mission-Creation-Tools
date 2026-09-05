# 04 — Unknown recurring patterns come back as proposed rules

Status: ✅ done

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

### Recorded as deferred, 2026-09-05

**No transport was wired, and that is deliberate.** The three routes are still exactly as costed
above and the choice is David's, not the implementer's: an automatic PR needs a credential in a
desktop tool, which the ticket itself calls a hard no; a local file depends on someone bothering;
and the Discord channel does not exist before lot 3. Picking one to close a checkbox would have
built the wrong one.

What ships is the proposal, rendered where the user already is: the *Explain* window shows the
candidate entries under **PROPOSITIONS DE RÈGLES**, in `rules.json` shape, and the whole analysis is
copyable. Someone who wants to contribute one can paste it into an issue today with no new
infrastructure — which is also, in practice, route 2 minus the file.

Measured on the real logs, the volume this has to carry is small: 1 to 5 proposals per log across
the live `dcs.log` and its 18 rotated archives.

## Definition of done

- [x] Recurrence detection over normalised messages, unit-tested on a fixture where the same error
      appears with varying identifiers
- [x] Candidate entries generated in `rules.json` shape, with a valid `match` regex
- [x] Generated regexes validated before being offered — an unanchored or catastrophic pattern is
      rejected rather than proposed
- [x] Nothing is written to `rules.json` automatically
- [x] The chosen delivery route implemented, or explicitly recorded as deferred with the reason
- [x] `poetry run pytest`, ruff check + format, mypy clean
