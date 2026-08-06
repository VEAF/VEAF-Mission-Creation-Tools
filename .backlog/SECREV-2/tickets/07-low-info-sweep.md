# 07 — The 108 low and info findings

Status: ⬜ ready
Type: chore
Findings: 95 🔵 LOW + 13 ⚪ INFO

## Sample before committing

These were **never adversarially verified** — the review says so plainly: its 96 UNVERIFIED findings
are "reviewer-asserted, not adversarially re-checked", and they are almost exactly this set. The
verifier refuted 6 of the findings it *did* examine, so an untested false-positive rate of several
percent should be expected here.

So this ticket does not open with 108 fixes. It opens with a **sample**:

- [ ] Take 15 at random across languages and kinds. For each, decide: still applies, already fixed, or
      does not reproduce.
- [ ] If the sample is mostly real, sweep by theme (the triage's `kind` field groups them:
      readability, optimization, error/bug).
- [ ] If a third or more do not reproduce, **stop and say so**. Bulk-fixing reviewer-asserted findings
      that nobody can reproduce is churn that looks like diligence, and it puts noise in the history of
      files people later have to read.

## What to do with the ones that do not reproduce

Record them in the triage as disproved, with one line of why. That is a real outcome and it is what
stops the next person re-reading the same 108 items in six months. The review's own Appendix B does
this for the 6 the verifier refuted — follow that precedent.

## Priorities within the tail

- **Error/bug** entries first: they are the ones that can actually bite someone.
- **Readability and optimization** last, and only where the file is being touched anyway. A
  readability fix in a file nobody is working in is a diff with no reader.
- **Documentation** entries: check them against the pages as they are now — a month of doc lots
  (`DOC-AUDIT-PASS`, `DOC-QUALITY-GATE`, `TOOLING-DOC-AUTOGEN`) has landed since, and several are
  likely closed already.

## Acceptance criteria

- [ ] The sample is done and its result is written down **before** any sweep starts.
- [ ] Every one of the 108 ends with an outcome in the triage — including "does not reproduce".
- [ ] No file is touched purely for readability unless something else was being changed in it.
