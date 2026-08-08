# 04 — Decide what to do with the historical documents

Status: ✅ done — decided 2026-08-08: **exempt, do not repair, do not delete yet**
Type: chore
Files: `docs/superpowers/plans/`, `docs/superpowers/specs/`, `CODE_DOC_REVIEW_2026-07-01.md`

## The question, for David

Eleven broken links live in documents that **describe a past state of the repo**:

- `docs/superpowers/plans/2026-06-24-backlog-restructure.md` (7) and its design spec (1) link to
  `backlog.md`, `CLEANUP-LUPA/PRD.md`, `RELEASE/PRD.md`, `archive/`. Those resolved when written:
  it is the plan **for** the restructure, describing the flat-`backlog.md` era it replaced.
- `CODE_DOC_REVIEW_2026-07-01.md` (8) is a dated review whose links were relative to `doc/`.

Three defensible answers, and the gate must not pick one on its own:

1. **Exempt them.** The gate does not police history. Cheapest, and keeps the record intact — but the
   exemption list grows every time a dated artefact lands.
2. **Fix the links.** Makes them resolve, at the cost of rewriting a record of a state that no longer
   exists into one that never existed. Actively misleading for a design document.
3. **Delete them.** The plan was executed and the review was actioned; git keeps them. Cleanest repo,
   loses the ability to read them without archaeology.

There is a reasonable split: exempt `docs/superpowers/` (genuine design history, worth keeping
readable) and delete or archive `CODE_DOC_REVIEW_2026-07-01.md` if its findings were all actioned —
`.backlog/archive/DOC-REVIEW.md` suggests they were.

## Tasks

- [x] Put the question to David with the three options.
- [x] Apply the answer — **option 1, exempt**. Repairing a record of a past state into a state that
      never existed is worse than a link that does not resolve, and that argument decided it.
- [x] Each entry in the exemption set carries its own reason comment (`veaf_build/docs_check.py`), so a
      later reader can tell a deliberate exemption from an abandoned one.
- [x] Deletion checked and **refused for now**: the split proposed in this ticket — delete
      `CODE_DOC_REVIEW_2026-07-01.md` since "its findings were all actioned" — was wrong. `SECREV-2`'s
      PRD sources its tickets from that file and **04 to 07 are still open** (01 in progress). It is
      live work, not a vestige. The delete-or-archive question reopens when `SECREV-2` closes.

## Notes

Ticket 01 ships with these exempted so the gate can be green while the question is open. That is a
placeholder, not the answer — this ticket is what closes it.
