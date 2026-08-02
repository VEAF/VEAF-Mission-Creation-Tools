# 03 — `resolve-checklist`: match, or fail with candidates

**Status:** ⬜ ready — depends on 01, 02. The heart of the lot.

`veaf-tools resolve-checklist <file.yaml>` fills in the technical fields of every stale step, in
place, and reports what it could not do.

## Matching

Normalise both sides — lowercase, strip accents and punctuation, drop noise words (`bouton`,
`switch`, `sur`, `to`, `set`) — then score each control of the index against the instructor's text:
words of the hint found in the text, words of the text found in the hint, and the position names.

`throttle sur idle` against `Throttle, OFF/IDLE` scores on both the control and the position; nothing
else in the F-16C index comes close. That is the ordinary case and it should just work.

## Failing well is the feature

The resolver is allowed to be conservative, because a wrong resolution is worse than no resolution:
it produces a checklist that looks finished and never ticks.

It **refuses**, listing what it found, when:

- no control scores above a floor — `bouton power` finds no hint containing "power";
- two controls score within a hair of each other;
- the position name is not among the control's `positions`;
- **the value cannot be derived** — which turns out to be far rarer than this ticket assumed. It was
  written believing the only sources were the hint's order (not value order) and in-game measurement,
  so a three-position switch would always have to be refused. **That was wrong**: an aircraft's input
  bindings (`Input/<Aircraft>/**/default.lua`) state the mapping outright —
  `MAIN PWR Switch - OFF` sets `-1.0`, `- BATT` sets `0.0`, `- MAIN PWR` sets `1.0`, matching what
  the previous lot measured in game to the digit, and `OFF/BACKUP` likewise gives 0/1. Ticket 01 now
  publishes this as `values:` per control. So the resolver **reads** the value, and only refuses when
  the control has no `values` entry: 104 of the F-16C's 284 controls have one (103 of them readable),
  87 of the F-14's 360 — an aircraft whose hints name *no* positions at all — but only 7 of the
  AH-64D's 478, whose panels and bindings do not share commands. Where `values` is missing the
  refusal stands, and ticket 04 remains how it gets closed.
- the control is `readable: false` — spring-loaded or a button. The message says to use `confirm`,
  and why.

Refusals go to the console, one line per step, with the top candidates and their scores. The file is
left alone unless every stale step resolved: a half-written file is worse than none.

## Tests

`test_resolve_checklist.py`: an ordinary match fills the fields and sets `resolved_from`; a
two-position control resolves its value with no help; a three-position one refuses and says why; an
unknown name refuses with candidates; a `readable: false` control refuses pointing at `confirm`; an
already-resolved step is untouched; a step whose `control` changed is re-resolved; nothing is written
when any step fails.

## Definition of done

- The F-16C checklist can be written from `control` texts alone, apart from the ambiguous values.
- `--dry-run` prints what would change without writing.
- Quality gate clean, coverage floor bumped.
