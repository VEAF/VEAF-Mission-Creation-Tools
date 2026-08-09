# 01 — Characterise the ten parsers before touching them

Status: ⬜ ready
Type: test

## Why first

Ten parsers have ten sets of quirks and some are load-bearing. Replacing them without pinning
what they do today turns a refactor into a behaviour change nobody can review — the diff would
show a parser being deleted and a parser being added, and no reader could tell which of the
differences were intended.

## Tasks

- [ ] For each of the ten `markTextAnalysis`, write tests covering: a well-formed command, a
      keyword with no value, a keyword with a non-numeric value, an unknown keyword, an empty
      command, and the keyphrase absent.
- [ ] Record the quirks that differ between modules rather than normalising them on the spot:
      which ones accept a valueless keyword as a flag, which treat `0` as absent, which are
      case-insensitive on values as well as keys, which stop at the first bad parameter and
      which carry on.
- [ ] Note the ones that look like defects. Do **not** fix them here — a characterisation test
      records what *is*, and a fix in the same commit is invisible.

## Acceptance criteria

- [ ] Every module's parser has tests that pass **before** any refactoring starts.
- [ ] The quirk inventory is written down in this ticket, with the deliberate ones separated
      from the accidental ones.
