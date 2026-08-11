# Lot TOOLING-REPO-LINK-GATE — the link gate stops at `doc/`, and the repo rotted behind it

Status: ✅ done

**Goal**: `docs-check` guarded the **published** documentation only. Everything else — `.backlog/`,
`docs/adr/`, `docs/exploration/`, `docs/agents/`, the root `*.md` — was unguarded: 340 markdown files
and 555 relative links, none of them checked.

Measured 2026-08-05: **92 of those links were broken.**

| # | Ticket | Status |
|---|--------|--------|
| 01 | Repo-wide relative-link pass in `docs_check` | ✅ |
| 02 | Fix the 68 links PR #655 broke | ✅ |
| 03 | Fix the `.fr.md` links | ✅ |
| 04 | Decide what to do with the historical documents | ✅ — exempt, do not repair, do not delete yet |
| 05 | CI triggers on the paths it checks | ✅ |

## A gate that would have caught its own absence

The trigger was noticing **three** dangling links while filing the dcs-sms lots. Three turned out to be
92 — and **68 of the 92 were a regression from PR #655**, the archive sweep.

That sweep folded each lot's tickets into a single archive file. A ticket lived three levels below the
repo root; the archive lives two. So every `../` chain in a ticket body climbed one level too far, and
`../PRD.md` lost its object entirely — the PRD was now *in the same file*.

The sweep called itself lossless, and by content it was. Link validity is not content, which is the
distinction this lot exists to enforce.

## Ticket 04, and the question it left armed

The three historical documents (`docs/superpowers/plans/`, `docs/superpowers/specs/`,
`CODE_DOC_REVIEW_2026-07-01.md`) were **exempted rather than repaired**, on David's call: repairing a
record of a past state into one that never existed is worse than a link that does not resolve.

Deletion was refused *for a stated reason with an expiry*:

> *`SECREV-2`'s live work sources findings from `CODE_DOC_REVIEW_2026-07-01.md`, so it is live work, not
> a vestige. **The delete-or-archive question reopens when `SECREV-2` closes.***

**`SECREV-2` closed on 2026-08-11**, with all 140 findings decided. So that condition is now met, and
the question is open again — which is worth knowing, because this archive is where it is written down.
