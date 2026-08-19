# 02 — Answer the round-trip question with a shared helper

Status: ✅ done — 2026-08-19. `test/python/testlib/writer_preservation.py` ships both helpers,
and the identity one **earned itself on its first two uses** by finding a second defect in the same
writer — see the PRD.
Type: chore
Files: `test/python/testlib/` (a new shared helper), the tests of the writers named below

## The question this answers

The PRD asks it in writing: **is there a check that a writer preserves what it did not mean to
change?** Three defects of that family surfaced on 2026-08-17 alone, all silent, all found by accident:

| Where | What it destroyed | Would a round-trip have caught it? |
|---|---|---|
| `warehouses_bootstrap` (`FIX-WAREHOUSES-LIST-FORM`) | the mission's own airfields, coalitions and stock | **yes** |
| `coalition_placeholder` (`FIX-GROUP-CONTAINER-SHAPE`) | nothing — it crashed, the lucky version | no (it raises) |
| `_update_build_config_in_yaml` (ticket 01) | any `mission.yaml` content after the build marker | **yes** |

Two of three. That is the answer, and it is worth more than either fix: the check is not per-defect, it
is per-writer, and every writer in this repository can be asked the same question.

## What ships

Two helpers in `test/python/testlib/`, which `pyproject.toml` already puts on the test path as the home
for shared test machinery:

- **`assert_round_trip_identical(path, writer)`** — read the file, invoke `writer` with **no intended
  change**, compare **bytes**. A writer that cannot reproduce its own input is a writer that is
  destroying something, whatever it thinks it is doing. On failure, a unified diff naming the lost
  lines, because "files differ" sends the reader back to where these three defects were found.
- **`assert_preserved(path, mutate, *needles)`** — for the intentional mutation: run `mutate`, then
  assert each needle is still in the file. Weaker than identity and necessary alongside it, since a
  writer that *must* change one section still has to leave the rest alone.

Applied here to `_update_build_config_in_yaml`. `FIX-GROUP-CONTAINER-SHAPE` uses the same helper for
its own "a mission nobody touched builds byte-identically" requirement, which is why this ticket lands
first.

## Deliberately not in scope

Sweeping every writer in the repository with the identity check. That is a lot of its own, and it would
turn a bounded fix into an open-ended audit — the helper existing is what makes that lot cheap later.
Say so here rather than leave it implied.

## Done when

- Both helpers exist in `test/python/testlib/`, with docstrings saying what each one catches
- `_update_build_config_in_yaml` is covered by both
- A failure message names the lost lines, not merely that the files differ
- The answer to the PRD's question is written into the PRD itself
