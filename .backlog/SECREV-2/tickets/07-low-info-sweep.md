# 07 — The 108 low and info findings

Status: 🔄 in-progress — sample done, tail is real, sweep not started
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


## Sample result, 2026-08-09

**15 drawn, stratified by `kind`, with a fixed seed (20260809) so the draw is auditable.**
11 could be decided from the code; 4 needed more context than a sample warrants and were left
alone rather than guessed at.

| Verdict | Count |
|---|---|
| Confirmed, still applies | **10** |
| Does not reproduce | **1** |
| Not decided in the sample | 4 |

**~9% did not reproduce, well under the third that would have meant stopping.** So the tail is
real and a themed sweep is justified — but the ticket's caution was worth honouring: one finding
in eleven was already dead, and finding that out cost minutes rather than a wasted fix.

The one that did not reproduce, recorded per the ticket's instruction:

- **VMR-072** — an unguarded `pilot.level` dereference in the server hook. The code reads
  `local pilot = veafServerHook.pilots[ucid]; if pilot then pilotData.level = pilot.level end`.
  Guarded. The hook was rewritten by `REFACTOR-SERVER-HOOK-CANONICAL` and `SECREV-2` ticket 02
  after the review was written.

### Two of the sample were fixed on the spot, being Error/bug

The ticket puts error/bug first, and these two were not really "low":

- **VMR-091** — `VeafMG_Guardian:copy` iterated `self.protectedUnits` and wrote each entry into
  `copy.protectedZone`. The next block then reassigns `copy.protectedZone = {}`, wiping the
  misplaced entries — so `protectedZone` ended up *looking* right while `protectedUnits` came
  back **empty**. Every copy silently lost its protected units. 5 tests.
- **VMR-074** — `activateZone`/`deactivateZone` looked up `zones[zoneName:lower()]` and indexed
  the result immediately. An unknown zone name crashed the command instead of being refused.
  Both functions had it; both are guarded now.

### What the sample says about the remaining 97

Worth reading before someone commits to "fix all 108":

- **66 are classed Error/bug.** On this sample's evidence most are real, and some are mislabelled
  as low — VMR-091 silently drops data and VMR-074 is a crash.
- **Documentation entries are the likeliest to be already dead**, as the ticket predicted: a month
  of documentation lots has landed since the review. VMR-119 is the exception and it is the same
  drifting-counter family that ticket 06 dealt with by *deleting* the counters.
- **Readability and optimization should stay last**, per the ticket. VMR-115 (11 `print()` calls)
  is in a one-shot migration script, not shipped code; VMR-108 is a real inefficiency with no
  wrong behaviour attached.
