# 03 — Nothing gets reported twice

Status: ⬜ ready

Type: feat

## Why it is cheap here

The corpus is tiny: **9 open issues** in total, and `.backlog/` is already in the agent's checkout.
Sweeping the existing work costs almost nothing, which is why this is not an optional refinement.

## What to build

Before drafting anything, the agent looks at four places:

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

- [ ] Sweep across open issues, closed issues, `.backlog/` and `ROADMAP.md`
- [ ] Each outcome implemented: duplicate, already fixed, lot in progress, nothing found
- [ ] A proposed match always shows its evidence and can be rejected by the user, who then continues
- [ ] What was checked is recorded in the draft
- [ ] Unit tests with the GitHub API mocked and a fixture backlog, one per outcome, including the
      rejection path
- [ ] Quality gate clean
