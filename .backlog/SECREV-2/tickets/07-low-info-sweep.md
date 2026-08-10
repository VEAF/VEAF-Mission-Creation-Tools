# 07 — The 108 low and info findings

Status: 🔄 in-progress — Error/bug tier under way: Python done bar 9, Lua started (79/140 decided)
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

### Where it stood after the Security-flaw tier

54 of 140 decided, 86 left.

## Sweep, third pass — every remaining CONFIRMED finding, 2026-08-10

**Batched by verdict rather than by theme.** The 56 open Error/bug findings are too many for one
reviewable change, and the ticket's warning about churn applies. The 10 the review's own verifier had
marked **CONFIRMED** were the obvious cut: already adversarially checked, so the lowest
false-positive rate available, and they happened to span all three ecosystems — 3 Python, 4 Lua,
3 documentation.

**There is now no CONFIRMED finding left undecided anywhere in the triage.**

| | Outcome | |
|---|---|---|
| VMR-052 | **fixed** | two bare `print()`, not one — plus a gate so the rule stops drifting |
| VMR-055 | **fixed** | hand-written spawn YAML gave a bare `KeyError` with no entry named |
| VMR-058 | **fixed** | `respawn_default_offset` indexed blind; a *string* emitted wrong Lua silently |
| VMR-076 | **fixed** | two `io.open` written before the guard, not one |
| VMR-077 | **fixed** | `logError` is defined nowhere — the error path was itself the error |
| VMR-081 | **fixed** | same shape, but inside DCS |
| VMR-092 | **fixed** | 7 occurrences across 2 files; `%s` alone would have been a half-fix |
| VMR-043 | **fixed** | `group N` is not a spawn option at all; both languages were wrong |
| VMR-045/046 | **fixed** | the CAS menu has no "Generate"; a `_cas` marker starts it |

### Four of the ten under-reported their own scope

The pattern from VMR-008 this morning (one reported link, 239 real) repeated four times:

- **VMR-052** — two `print()` calls, the second unmentioned.
- **VMR-076** — two unguarded `io.open`, the second unmentioned.
- **VMR-092** — **7** eager `string.format("%d", val)` across `veafMove` **and**
  `veafTransportMission`, against one line reported.
- **VMR-043** — the French `GUIDE.md` carried the same invalid advice as the English page.

Reading the finding and fixing the cited line would have left most of each defect in place.

### Measuring changed two fixes, and my own grep lied

- **VMR-092**: the obvious fix is `%d` → `%s`. Measured in Lua 5.1, `string.format("%s", nil)`
  **also raises** — and nil is exactly what `_move speed` with no value produces. `tostring()` is
  required; `%s` alone would have shipped a fix that still crashed on the simpler typo.
- **VMR-043**: my first rewrite described `spacing` as a distance in hundreds of metres. The code
  computes `cell.width = default + spacing * default` — it is a multiplier of the vehicle's own
  footprint. Inventing a unit in pilot-facing documentation is exactly the failure this ticket keeps
  finding.
- **VMR-052**: I concluded "zero `print()` left" from `grep -r "^\s*print("`, which finds nothing
  because `\s` is not BRE without `-E`. The AST-based gate immediately found eleven in
  `migrate_lazy_log.py`. A broken measurement reads exactly like a clean result.

### The rule that had no gate

CLAUDE.md forbids `print()` outright — `veaf_libs.logger` exists so output can be muted (the MCP
server silences the console because stdout carries its JSON-RPC stream) and routed to a file. Nothing
checked it, and it drifted. `test/python/test_no_bare_print.py` now parses the whole shipped package
with `ast` instead of grepping, since a regex counts `print(` inside comments, docstrings and
`pprint(`. It has one exemption, named rather than pattern-matched: `migrate_lazy_log.py`, whose
console output *is* its deliverable (this also settles what VMR-115 was about).

### Writing the tests found a bug in my own fix

`t()`'s first parameter is named `key`, so `t("...", key=...)` raises `TypeError: got multiple values
for argument 'key'`. It was in the VMR-055 fix, where a test caught it, **and** in the VMR-058 fix,
where no test had reached it yet — it would have failed the first time a mission maker hit the error
path, which is the worst possible moment for an error message to be broken.

### Where it stood after the CONFIRMED sweep

**64 of 140 decided. 76 left**, of which 46 Error/bug, 9 Documentation, 3 Security flaw (the
shared-password family awaiting David), and 18 readability/optimization/refactoring the ticket says to
touch only where a file is being changed anyway. **None of the 76 is CONFIRMED** — the rest are
UNVERIFIED or PLAUSIBLE, so the next batch should expect the sample's ~9% that do not reproduce.

## Sweep, fourth pass — Error/bug, Python batch 1, 2026-08-10

The 39 remaining Error/bug findings split 13 Python / 26 Lua across 35 files, so they go in batches by
ecosystem rather than one change. This is the first Python batch: **7 findings, all confirmed against
the code, all fixed.**

| | Outcome | |
|---|---|---|
| VMR-070 | **fixed** | a forecast group overwrote the observed visibility |
| VMR-065 | **fixed** | `exit()` is `site`'s, not the language's — **10** occurrences, not 1 |
| VMR-060 | **fixed** | coordinates emitted as strings, and the point *name* unescaped |
| VMR-067 | **fixed** | one nameless group crashed the whole extraction |
| VMR-056 | **fixed** | a non-numeric trigger key crashed the index search |
| VMR-059 | **fixed** | a guard whose default made it always true |
| VMR-069 | **fixed** | an avwx API change was indistinguishable from an outage |

### The regex lied again, and the count went 1 → 8 → 10

VMR-065 named one `exit()`. A regex found 8. The AST-based gate then found **10**: the two `exit(1)`
forms were not alone on their line, so `^\s*exit\(\)$` skipped them. That is the third time in this
ticket that a hand-written pattern under-counted what an AST pass sees — the same lesson as the
`print()` gate this morning, learned again in the same afternoon.

Replacing them turned up dead code for free: `prepare.py` called `exit(1)` **after** `logger.error`,
which raises `typer.Abort` by default. The line could never run.

### VMR-070's mechanism is worse than its title

"Visibility regex matches unrelated 4-digit tokens" undersells it. The branch has no `break`, so the
**last** four-digit group won — and everything from `TEMPO`, `BECMG`, `PROB` or `RMK` onwards is a
*forecast*, not the observation. A report observed at 9999 and ending in `TEMPO 3000` was flown at
3000 m. The parser now stops at those words and keeps the first prevailing visibility.

### Two findings under-reported their scope, again

- **VMR-060** mentions unescaped coordinates but not the point's **name**, interpolated raw in the
  same line: a quote in a point name produced Lua that does not parse.
- **VMR-065**, above.

### And I over-engineered once, caught by the existing tests

My first VMR-070 fix added an `i > 0` guard against reading a numeric station identifier as a
visibility. ICAO codes are alphabetic, so it protected nothing — and it broke two existing tests that
parse a bare `"9999"`. Removed. A guard against an impossible input is not caution, it is noise that
breaks real cases.

### Where it stands

**71 of 140 decided. 69 left**: 39 Error/bug (13 Python, 26 Lua), 9 Documentation, 3 Security flaw
(awaiting David), 18 readability/optimization/refactoring to touch only where a file is being changed
anyway.

## Sweep, fifth pass — Error/bug, Python batch 2, 2026-08-10

Four more, and one of them taught the sharpest lesson of the ticket.

| | Outcome | |
|---|---|---|
| VMR-063 | **fixed** | an unreadable installed version claimed an update on every run |
| VMR-047 | **fixed** | an indexed DCS table crashed the unit count; half the finding is obsolete |
| VMR-064 | **fixed** | the `ask` REPL died on any error that was not a RuntimeError |
| VMR-128 | decided-deferred | vendored third-party code, and we never pass the argument |

### My first three tests for VMR-063 passed for the wrong reason

They asserted that nothing is printed when the installed version is unreadable — and nothing was
printed, but not because of the fix: my cache mock used `checked_at` where the code reads
`last_check`, so the cache was ignored, the code went to the network, and the exception was swallowed
by the surrounding `except Exception: pass`. Three green tests exercising nothing.

What caught it was writing the **control**: a readable *older* version must still prompt. It failed,
and that failure is what proved the rest was hollow. Same shape as the coverage rule that extracted
zero names and the grep that reported zero prints — a test that cannot fail is indistinguishable from
a test that passes.

### VMR-047 was half obsolete

`_max_ids`, one of the two functions named, no longer exists. The other half is real: a Lua sequence
only reaches Python as a list while its keys are 1..n with no gap, and deleting a country or a group
in the Mission Editor brings the field back as a dict keyed by the survivors. Iterating that yields
the **keys**, so `country.get(...)` ran on a string.

### Where it stands

**75 of 140 decided. 65 left**: 35 Error/bug (**9 Python, 26 Lua**), 9 Documentation, 3 Security flaw
(awaiting David), 18 readability/optimization/refactoring to touch only where a file is being changed
anyway.

## Sweep, sixth pass — Error/bug, Lua batch 1 (dcsDataExport + MissileGuardian), 2026-08-10

Four findings, and one of them is the most consequential of the whole ticket.

| | Outcome | |
|---|---|---|
| VMR-079 | **fixed** | `arg` is **nil** inside a Lua 5.1 vararg function — every formatted log call was broken |
| VMR-090 | **fixed** | all three remote commands called functions that do not exist |
| VMR-080 | **fixed** | the skip list was written into the caller's own table |
| VMR-078 | **fixed** | `log:error` — the error path was the error, again |

### VMR-079 is not a portability note, it is a live defect

The finding says reliance on `arg` "breaks under Lua 5.2+". Measured on Lua 5.1:

```
inside a vararg function -> arg type: nil
inside a plain function  -> arg type: table
```

`arg` is **nil** inside a vararg function — the global `arg` holds the script's command-line
arguments, which is why it looks defined from outside. So `formatText`'s format branch never ran, and
the five logger methods called `unpack(arg)` on **nil**, which raises. The only thing standing between
that and a crash is `LUA_COMPAT_VARARG`, a compile-time option of whichever Lua DCS ships — not
something we can rely on, and not something we can check from here.

All six occurrences now use `{...}`. `mist.lua` has the same pattern six more times and was left
alone: third-party community code.

### VMR-090: all three branches were dead, not one

`listAvailableMissions`, `ActivateMission` and `DesactivateMission` do not exist. The module was
renamed *mission* → *guardian* and its remote handler never followed, so **every** remote command
raised. Mapped onto the real `listGuardians`, `ActivateGuardian`, `DesactivateGuardian`.

**Found in passing and deliberately not fixed**: `listGuardians` sorts and iterates an *empty local
table*, so it always prints an empty list. That is a separate defect, outside this finding, and fixing
it needs someone to say what it should collect.

### No new tests in this batch, and why

`dcsDataExport.lua` cannot be loaded outside DCS — it indexes a global `db` the sim provides — and
`veafMissileGuardian`'s remote handler needs a mock fleet this ticket has no business building. The 36
existing Lua suites pass, `stylua` and the CI `luacheck` gate cover the syntax, and the `arg`
behaviour was established by direct measurement rather than by assertion. Saying so is better than
shipping a harness bodged together at the end of a sweep.

### Where it stands

**79 of 140 decided. 61 left**: 31 Error/bug (**9 Python, 22 Lua**), 9 Documentation, 3 Security flaw
(awaiting David), 18 readability/optimization/refactoring to touch only where a file is being changed
anyway.
