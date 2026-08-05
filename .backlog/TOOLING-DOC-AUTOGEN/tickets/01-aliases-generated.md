# 01 — Generate `ALIASES.md` from `veaf-units.yaml`

Status: ⬜ ready
Type: feat
Files: `veaf_build/` generator, `doc/ALIASES.md` (+ `.en.md` if it exists), `test/python/`

## Why this one first

It is the cheapest and the least arguable: `doc/ALIASES.md` is 8 KB whose entire content is a
rendering of `veaf_libs/data/veaf-units.yaml`. There is no prose to lose.

## Behaviour

- A generator command writing the doc from the YAML, with a header naming itself so nobody hand-edits
  the output and loses the edit on the next run.
- Compare the current committed file against the generated one **before** replacing it, and read the
  diff: any difference is either a bug in the generator or a fact the doc had that the data does not.
  The second case is the interesting one — it means the YAML is missing something, and that should be
  fixed in the YAML, not papered over in the template.
- Both language variants if `ALIASES` is published in both.

## Tasks

- [ ] Generator implemented, output header states the command that produces it.
- [ ] Diff between hand-written and generated reviewed line by line; anything the doc knew and the
      data did not is moved **into the data**, and that is called out in the PR.
- [ ] Committed file replaced by the generated one.
- [ ] Unit tests on the rendering, not just a golden file — a golden file alone passes forever after a
      bad regeneration.

## Acceptance criteria

- [ ] Regenerating produces no diff.
- [ ] `docs-check` clean (links, anchors, both languages).
- [ ] `ruff` / `mypy` / `pytest` green over the whole tree; coverage gate bumped per the ratchet.
