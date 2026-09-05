# 05 — Prepare a report block the intake flow can read

Status: ✅ done

Type: feat

## The idea

The moment the analyser says *pattern not catalogued* is the moment the user is both most motivated
to report and best equipped to do it: he has the log open, the filter applied, and he has just
learned the problem is unknown. Making him start again from a blank Discord message throws all of
that away.

## What to build

A *Prepare a report* action that assembles, in one block:

- the output of `veaf-tools doctor` ([`FEAT-SUPPORT-DIAGNOSTIC` ticket 01](../../FEAT-SUPPORT-DIAGNOSTIC/tickets/01-doctor-command.md)),
- the bounded, redacted excerpt from [ticket 01](01-bounded-excerpt.md),
- the catalogue matches and what the analysis concluded, including what it could not explain.

Copied to the clipboard, ready to paste into `/bug`. That block **is the contract** between this
lot and [`FEAT-SUPPORT-BUG-INTAKE`](../../FEAT-SUPPORT-BUG-INTAKE/PRD.md): versioned, parseable,
and documented on both sides.

It also settles the 11 MB problem for good — what travels is an excerpt the machine already bounded,
not a file nobody can upload.

## Notes

- This is a **paste**, not a transmission. Sending straight to the service would require pairing a
  desktop install with a Discord account, an authentication mechanism the project does not have and
  that this programme deliberately does not build.
- The block must survive a round trip through Discord's Markdown — code fences, no character that
  breaks the rendering, a length that does not exceed a message.
- If it does exceed it, the block says so and states what was trimmed, rather than being silently
  cut at the boundary.

## Definition of done

- [x] A *Prepare a report* action producing the assembled block on the clipboard
- [x] Block format versioned and documented, in a place the intake lot can point to
- [x] Fits a Discord message, or states its own truncation
- [x] Redaction verified on the assembled block, not only on its parts
- [x] A round-trip test: the block is parsed back and yields the fields the intake flow expects
- [x] `poetry run pytest`, ruff check + format, mypy clean
