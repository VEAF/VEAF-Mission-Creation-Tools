---
status: accepted
---

# One backlog index per status, the README a front page

Amends [ADR 0009](0009-backlog-restructure.md), which made `.backlog/README.md` the single,
hand-maintained lot index.

By 2026-10-03 that index was 296 KB and 501 lines: one table for the 58 lots on disk and the 418
archived ones, and the rows of the active lots had grown into paragraphs (the longest ~4 000
characters). Finding what was left to take meant reading all of it, and reading it cost an agent a
large slice of its context for every backlog question.

## Decision

- Every lot on disk sits in the index of its status, as a `###` heading holding the link to
  its `PRD.md` and its status icon, then a one- or two-line summary: `ACTIVE.md` (🔄 in progress, 🧑 waiting for a human, ⏸ paused in a
  section of its own), `READY.md` (⬜), `DONE.md` (✅, 🚫 — until archived).
- `.backlog/README.md` is a front page: per index, a count per status and the list of links.
- Archived lots keep their former table, moved unchanged to `.backlog/archive/README.md` (David: not
  in the three indexes).
- Still maintained by hand, no generator. `test_backlog_status_consistency.py` checks that every lot
  is listed once, in the index of its PRD status, and that the front page's counts and lists match.
- The long former rows were not dropped: each one was appended verbatim to its PRD under *Former
  index entry*, since they paraphrased the PRD rather than quoting it and no automatic comparison
  could tell new information from rewording.

## Consequences

- A status change is now a **move** between files, not an edit of one cell — the new way to be
  wrong, which is why the gate checks the index against the status.
- The summary is written for someone choosing what to read next: what the lot is, then what is left.
  The detail lives in the PRD.
