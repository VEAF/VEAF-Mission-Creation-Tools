# 03 — Nothing gets reported twice

Status: ✅ done

Type: feat

## Why it is cheap here

The corpus is tiny: **9 open issues** in total, and `.backlog/` is already in the service's checkout.
Sweeping the existing work costs almost nothing, which is why this is not an optional refinement.

## What to build

Before the preview is rendered, the service looks at four places — all of it text matching, no model involved:

| Source | Answers |
|---|---|
| Open issues | is this already reported? |
| Recently closed issues | was this fixed in a version the user does not have? |
| `.backlog/<LOT>/` | is a lot already working on it? |
| `ROADMAP.md` | is it deliberately parked or cancelled? |

`CONTRIBUTING.md` is explicit that issues are an intake desk and the real work lives in lots, so
issues alone would miss most of the answer.

## What it does with the answer

- **Already reported**: comment on the existing issue with the new observation instead of opening a
  second one, and tell the user in the thread which issue it is.
- **Already fixed**: answer in the thread with the version that fixed it, and open nothing. This is
  the most valuable outcome — the user is unblocked immediately.
- **A lot is on it**: say so, with the lot, and open nothing.
- **Nothing found**: proceed, and record in the draft what was checked, so the reader knows the
  sweep happened.

## The failure mode to guard

A wrong "this is a duplicate" silences a real bug, and the user will not insist. So a match is
proposed with its evidence, and the user can say *no, mine is different* and continue — the sweep
informs the decision, it does not take it.

## Definition of done

- [x] Sweep across open issues, closed issues, `.backlog/` and `ROADMAP.md`
- [x] Each outcome implemented: duplicate, already fixed, lot in progress, nothing found
- [x] A proposed match always shows its evidence and can be rejected by the user, who then continues
- [x] What was checked is recorded in the draft
- [x] Unit tests with the GitHub API mocked and a fixture backlog, one per outcome, including the
      rejection path
- [x] Quality gate clean

## What was built

`veaf_support_bot/priorart.py`. The corpus is four kinds of candidate; the score weights *signal*
tokens — identifiers, file names, versions, anything that is not everyday vocabulary — three times
an ordinary word, and a proposal needs either a shared signal token or five shared ordinary ones.
The algorithm is deliberately legible: the score is printed with the words it was computed from, so
a maintainer who thinks it is wrong can see why it is wrong. A similarity model would score better
and explain nothing — and would cost a call this lot does not have.

The version that carries a fix is a **lookup, not a guess**: the changelog cites issues as
`[#123](…/issues/123)`, so the version is the nearest `## [x.y.z]` heading above the citation. An
issue the changelog does not mention yields no version and the message says so.

Only **open** lots are candidates. Proposing a `✅ done` lot would tell a reporter his bug is being
worked on when it shipped months ago — the same silencing failure as a wrong duplicate.

## Two decisions worth revisiting

1. **With nobody to ask, the gate answers "rejected".** Ticket 04 owns the click that asks; until it
   exists the sweep runs, the finding is printed with its evidence and attached to the issue, and
   the report is filed. The alternative — auto-accepting a high-confidence match — would silence
   reports on a machine's unverified conclusion, which is exactly what this ticket forbids.
2. **The attached log is not part of the query.** A log shares hundreds of words with every other
   log; including it would match a report against everything and teach reporters to dismiss the
   proposal. The query is the reporter's own words plus what the trace named.
