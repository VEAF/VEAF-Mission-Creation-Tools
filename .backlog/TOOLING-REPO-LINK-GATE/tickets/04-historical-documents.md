# 04 — Decide what to do with the historical documents

Status: 🧑 waiting-human
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

- [ ] Put the question to David with the three options.
- [ ] Apply the answer.
- [ ] If exempting: each entry in the exemption set gets its own reason comment, so a later reader can
      tell a deliberate exemption from an abandoned one.
- [ ] If deleting: check nothing links **to** them first.

## Notes

Ticket 01 ships with these exempted so the gate can be green while the question is open. That is a
placeholder, not the answer — this ticket is what closes it.
