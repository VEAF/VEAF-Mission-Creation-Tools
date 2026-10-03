# CHORE-BACKLOG-INDEX-SPLIT — one index per kind of lot, each lot a short paragraph

Status: ✅ done — merged in #1058 (2026-10-03)

Origin: David, 2026-10-03. `.backlog/README.md` had grown to 296 KB and 501 lines: one table holding
the 58 lots on disk and the 418 archived ones, and the rows of the active lots had turned into
paragraphs (the CTLD logistics row alone is ~4 000 characters). Finding what is left to take meant
reading all of it.

## Decision

- `.backlog/README.md` becomes a front page: per index, a count by status and the clickable list of
  its lots.
- Three indexes for the lots on disk, one paragraph per lot (a heading carrying the link and the
  status icon, then one or two lines):
  - `ACTIVE.md` — 🔄 in progress, 🧑 waiting for a human, and ⏸ paused in a section of its own;
  - `READY.md` — ⬜ ready to take;
  - `DONE.md` — ✅ done and 🚫 wontfix, not yet archived.
- The archived lots are **not** in those indexes (David): their table moves unchanged to
  `archive/README.md`, which the front page links with its count.
- Nothing said in a former index row is lost: every row is appended verbatim to its PRD under
  *Former index entry* (the rows paraphrased their PRD, so no automatic comparison could tell new
  information from rewording).

## Tickets

| # | Ticket | Status |
|---|--------|--------|
| 01 | [Split the index and write the summaries](tickets/01-split-the-index.md) | ✅ |
| 02 | [The consistency gate reads the new indexes](tickets/02-consistency-gate.md) | ✅ |
| 03 | [Docs and instructions name the new layout](tickets/03-docs.md) | ✅ |

## Definition of done

- [x] Every lot directory appears in exactly one of the three indexes, the one matching its PRD status.
- [x] The front page's counts and lists match the indexes, checked by a test.
- [x] `test_backlog_status_consistency.py` reads the new layout and fails on a lot in the wrong index.
- [x] `docs-check` green (links in the moved archive table rewritten).
- [x] `docs/agents/issue-tracker.md`, `CLAUDE.md` §2/§6/§8, `copilot-instructions-generic.md`, and an ADR.
