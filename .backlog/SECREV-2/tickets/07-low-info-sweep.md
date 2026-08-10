# 07 — The 108 low and info findings

Status: 🔄 in-progress — sample done, HIGH tier cleared, Security-flaw tier swept (54/140 decided)
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

## Sweep, first pass — 2026-08-10

**Every HIGH and CRITICAL finding now has an outcome.** Four were still marked undecided, and
checking them against the code rather than against the PRD is what this pass was for:

| | Outcome | |
|---|---|---|
| VMR-005 | already-fixed | closed by ticket 05; only the triage entry had not been updated |
| VMR-006 | already-fixed | idem — `metar.update()` is there, with the VMR-006 rationale beside it |
| VMR-007 | **fixed** | still applied, and in **both** languages |
| VMR-008 | **fixed** | still applied, and **far wider** than reported |

### VMR-008 was one finding hiding 239

The review reported one English page linking to a French one. Measured across the tree: **239 links
on 38 `.en.md` pages** sent an English reader to the French version of a page that *has* an English
one. All rewritten.

The reason it accumulated is the interesting part. `docs_check` already knew about the situation — it
**followed the twin** to check anchors on the page the reader would land on — and thereby compensated
for the mistake in silence instead of reporting it. It now reports it, and the rule was verified by
reintroducing a bad link and watching it fail. A checker that quietly works around a defect is worse
than one that ignores it, because it makes the defect invisible.

### VMR-007 was nearly missed for a stupid reason

`grep "coming next"` on the English page found nothing, so it looked fixed. The phrase is split
across two lines. It said "(coming next)" while `veaf_libs/data/convert-profiles/` has shipped
`foothold.yaml` and `foothold-ww2.yaml` for months. Both pages now name them.

### Error/bug tail, two of the same shape

| | Outcome | |
|---|---|---|
| VMR-049 | **fixed** | the auto-downloaded `dcs-bridge.lua` temp file was never deleted |
| VMR-057 | already-fixed | the updater's temp zip is already in a `try/finally` |

VMR-049 carried a trap worth recording: the caller cannot simply delete what it is handed, because
the same argument also carries a `lua_path` the mission maker supplied. The worker remembers which
file *it* created; two tests cover both sides.

### Where it stands

**47 of 140 decided. 93 left — all LOW or INFO**, of which 56 Error/bug, 10 Security flaw, 9
Documentation, and 18 readability/optimization/refactoring the ticket says to touch only where a file
is being changed anyway.

Stopped here deliberately rather than pushing further in one sitting: the ticket's own warning is
that bulk-fixing reviewer-asserted findings is "churn that looks like diligence", and a sweep of
this size wants reviewable batches.

## Sweep, second pass — the Security-flaw tier, 2026-08-10

**The 10 undecided Security-flaw findings, all of them, taken as one batch.** They were the right
next group: small enough to finish, and the one tier where being wrong costs more than churn.

Every verdict below came from reading the code, not from the review's wording — and the wording was
wrong or overstated in three of the ten.

| | Outcome | |
|---|---|---|
| VMR-034 | **fixed** | size cap on the bridge download; no host to attack, and pinning a hash would fight the design |
| VMR-035 | **fixed** | real path traversal, *reproduced* by disabling the new guard |
| VMR-036 | **fixed** | confirmed, but the reported batch injection is unreachable; the real defect was a failed `cd` |
| VMR-037 | **fixed** | the URL of an executable we install and run is now checked |
| VMR-038 | does-not-reproduce | `setfenv(file, {})` — the empty environment the finding missed |
| VMR-041 | decided-deferred | real, self-documented, belongs to `REVIEW-SECURITY-LAYER` |
| VMR-042 | does-not-reproduce | `:upper()` narrows the key space to `FOG_*`; fragility removed anyway |

### VMR-035 was the one that mattered, and it was worth proving

The others are hardening. This one moved a file out of the mission folder. `_normalize_script_names`
joined the profile's replacement string straight onto `scripts_dir`, and `load_profile` accepts a
**filesystem path** as well as a bundled name — so the replacement is not necessarily one we ship,
and profiles are exactly the kind of file that gets passed around.

Rather than assert it, the guard was disabled and the run measured: `escaped.lua` appeared in the
parent folder and `victim.lua` was gone. A security test nobody has watched refuse is a decoration.

### Three of ten were overstated, and saying so is the deliverable

- **VMR-038** claimed a dictionary file is executed untrusted. It runs under `setfenv(file, {})` —
  an empty environment, no `os`, no `io`, no `require`. The same trap a previous session fell into
  by taking "RCE" at face value.
- **VMR-042** claimed a missing whitelist on a player-supplied key. `:upper()` already restricts it
  to the all-caps keys, and **every** all-caps key on `veafWeather` is a fog preset — measured, not
  assumed.
- **VMR-036** named batch injection. Windows forbids `"` in a path, so nothing can escape the
  quotes. But looking for the real consequence found one: a failed `cd` left every relative
  `ren`/`del` running in the wrong directory.

### Left for David — the shared-password family

**VMR-039, VMR-040 and VMR-033 are one question, and it is not a technical one.** Two unsalted SHA-1
password hashes ship in `veafSecurity.lua` as defaults common to all missions, and `veafRemote` will
run stored Lua for whoever clears the ADMIN tier. The hashes are in a public repository, so an
offline dictionary attack is available to anyone.

The remedies pull against each other:

- Changing the hashing breaks every server and mission that uses the current passwords.
- Documenting that the default password is well known is the honest, cheap mitigation — **and it
  also tells attackers exactly where to look**, on the servers that never changed it.

That trade-off is David's, not mine, so all three stay undecided rather than being quietly resolved
in a sweep. Nothing else in the tier depends on the answer.

### The first version of the VMR-037 fix had the same hole it was closing

Worth recording, because it is the failure mode this whole ticket is about. The guard checked the URL
handed to `download_asset` and then called `requests.get` — **which follows redirects to any host by
default**. A 3xx off GitHub would have been followed regardless of the check. Sourcery caught it on
the PR.

The chain is now walked one hop at a time, each hop checked before it is requested. Chasing that
turned up a second problem nobody had reported: walking redirects by hand means `requests` no longer
strips the `Authorization` header across hosts, so the user's GitHub token would have been handed to
whatever host the redirect named. Both are covered by tests, including one asserting the untrusted URL
is **never requested** — refusing after fetching is not refusing.

### Where it stands

**54 of 140 decided. 86 left**, of which 56 Error/bug, 9 Documentation, 3 Security flaw (the family
above), and 18 readability/optimization/refactoring the ticket says to touch only where a file is
being changed anyway. The Error/bug tier is the next batch.
