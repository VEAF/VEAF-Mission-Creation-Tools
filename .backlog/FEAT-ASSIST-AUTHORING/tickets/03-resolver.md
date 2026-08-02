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
- **the value cannot be derived.** The index gives positions in hint order, which is not value order.
  A two-position control with `range: [0, 1]` is unambiguous. A three-position one is not:
  `MAIN PWR/BATT/OFF` may run +1 → −1 or the reverse, and the resolver must say so rather than pick.
  In-game verification (ticket 04) is what closes this; until then the instructor supplies the value.
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
