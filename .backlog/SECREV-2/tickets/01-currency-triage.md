# 01 — Currency triage: method, tooling, and the eight verified

Status: 🔄 in-progress
Type: chore
Files: [`findings-triage.json`](../findings-triage.json)

## Why this is first

The review is a month old and 140 findings deep. Executing it without checking what still applies
would mean fixing things already fixed and, worse, reporting confidence about code nobody re-read.

## Method

Each finding carries a file and usually a line. That gives three mechanical classes:

- **moot** — cited file gone. (None, as it turns out.)
- **untouched** — file unmodified since 2026-07-01, so the finding almost certainly stands.
- **review-needed** — file changed since; the commits are listed so the next person reads *that diff*,
  not the whole file.

This does not decide whether a finding is real — the review's own verifier did that for the CONFIRMED
ones. It decides **where judgement is still needed**, turning "verify 140 findings" into "read 70
diffs, most of them small".

The extractor parses the `#### VMR-0NN — title` / severity / verdict / `path:line` shape the review
uses consistently. Regenerating it is seconds of work and re-dates every status.

## Delivered 2026-08-05

- [x] All 140 findings extracted to `findings-triage.json` with id, title, severity, kind, verdict,
      path, line, status and the commits touching the file since the review.
- [x] 70 untouched / 70 review-needed / 0 moot.
- [x] **The eight CRITICAL and HIGH verified by hand against current code** — see the PRD table.
      Seven still stand; **VMR-008 is disproved**, and by the repo's own earlier measurement rather
      than by opinion.
- [x] Two cross-references established: VMR-026 was already fixed by `TOOLING-REPO-LINK-GATE`, and
      VMR-013 is load-bearing for `FEAT-DCS-SMOKE-HARNESS`.

## A trap worth recording

Three of these checks first gave a **wrong answer to a grep**:

- `grep -A 4` on an alias declaration cut off before the line that mattered.
- `grep "coming next"` missed VMR-007 because the phrase **wraps across two lines** in the source — it
  reported the finding as fixed when it is not.
- A `git status` that printed nothing was read as "tracked and clean" when the file was **ignored**.

Every one of them would have closed a live finding as done. When checking whether a finding still
applies, read the surrounding lines rather than trusting a pattern match, and prefer a negative that
you can see the shape of.

## Remaining

- [x] Verify the 24 MEDIUM the same way — done by ticket 06 as it went, and all 24 carry an outcome.
- [ ] Sample the LOW/INFO rather than verifying all 108 individually (ticket 07, in progress: 91 of
      140 findings decided across the whole review, 49 left).

Nothing else in this ticket is actionable: it closes when ticket 07 does.
