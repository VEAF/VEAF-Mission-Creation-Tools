# 07 — The 108 low and info findings

Status: 🔄 in-progress — Security-flaw, Documentation and **Error/bug** tiers all closed; 122/140 decided, only the 18 cosmetic findings remain and this ticket's own policy reserves them for files being changed anyway
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

## The shared-password family, decided by David — 2026-08-10

**VMR-039 / VMR-040 / VMR-033, the three findings this ticket deliberately left open.** David's answer
came with the release plan (release last, FC3 frequencies tested then, central config repo already
done), and checking the code before asking him **dissolved the dilemma I had put to him**.

I had framed it as a choice between breaking every existing server (change the hashing) and merely
documenting the weakness (which also tells attackers where to look). Both premises were wrong:

- `password_MM` has **always** been replaced by the generator — `veafSecurity.password_MM = {}` before
  the adds — while `password_L1` was only *extended*. Three lines apart, same function. So declaring
  your own passwords **widened** the accepted set instead of closing it, and the hash published in the
  repository kept opening the mission.
- The fix is therefore neither destructive nor cosmetic: clear before adding, exactly as Mission
  Master already did.

`L0` is cleared too, and that is the part worth remembering: `checkPassword_L1` accepts **L1 or L0**,
so leaving the shipped L0 hash in place would have made the whole change decorative. Consequence: on a
mission that declares its own hashes, nothing grants ADMIN *by password* any more — ADMIN comes from
the pilot's level in `veaf-pilots.txt`, which is how a server identifies its administrators anyway.
Missions that declare nothing keep the shipped defaults, so nothing changes under anyone's feet.

The unsalted SHA-1 is untouched, on purpose: **a known password is known whatever the digest**. Being
able to turn it off is the fix that matters.

### The documentation said SHA-256 while the code hashes SHA-1

Found while checking whether a mission can define its own passwords at all. `mission.yaml`, the
generator's template, the MCP action's docstring and **both** GUIDE pages said SHA-256;
`veafSecurity._checkPassword` calls `sha1.hex(password)`. A mission maker following the documentation
produced a hash that can never match — believing access was restricted while only the public default
still worked.

All five corrected. And a nuance I owe: `MISSION_YAML_REFERENCE` **already** carried a "SHA-1, not
SHA-256" warning saying the page had been fixed. The repo had caught this in one place and left it
wrong in five others, so this was a half-finished correction, not a discovery.

### SHA-256 support: proposed, then withdrawn on cost

I recommended also accepting SHA-256 so new missions could use it. Then I looked: **there is no SHA-256
implementation anywhere in the Lua tree**, and Lua 5.1 has no bitwise operators — it would mean
carrying ~200 lines of hand-written crypto in pure arithmetic. That is not the modest addition I sold
it as. Split out rather than improvised at the end of a session; the doc fix already removes the trap
that made it urgent.

### Where it stands

**82 of 140 decided. 58 left, and none is a Security flaw** — the tier is closed. What remains: 31
Error/bug (9 Python, 22 Lua), 9 Documentation, 18 readability/optimization/refactoring to touch only
where a file is being changed anyway.

## Sweep, seventh pass — Error/bug, Lua batch 2, 2026-08-10

Three findings, and two of them show why reading the code beats reading the finding.

| | Outcome | |
|---|---|---|
| VMR-097 | **fixed** | every CAP flew its whole route at Mach 0.3 |
| VMR-071 | **fixed** | a real defect, but the finding's remedy was inverted |
| VMR-075 | **fixed** | `veafServerHook` in a script that has never heard of it |

### VMR-097: four different speeds, one result

`convertSpeeds(speed, mach, altitude)` took `mach` and ignored it, using a hard `0.3`:

```lua
result = veaf.convertMachSpeed(0.3, altitude).TAS_ms   -- mach never read
```

The four legs are called with **0.3, 0.5, 0.63 and 0.63**. So every CAP spawned without an explicit
speed flew its entire route at Mach 0.3 — sluggish patrols, in game, for anyone who never passed a
speed.

### VMR-071: right that it is broken, wrong about why

`statisticsTypes` was a plain list, so `pairs()` handed the loop the **Lua index** (1..8) and the code
passed that to `net.get_stat` — reading whatever ids 1..8 happen to be and filing them under the wrong
names.

But the finding proposes passing the list's *value* instead, i.e. the string `"ping"`. The repo's own
API schema settles it:

> `@param statID number` Statistic identifier (one of the `net.PS_*` constants).

A string would not have worked either. The table now maps each reported name to its **constant name**,
resolved through `net[...]` at the call — which removes any assumption about the numeric values, since
the schema documents them only as `number`. A DCS version that drops a constant now skips that one
statistic with a warning instead of calling `get_stat` with nil.

Worth noting where the answer came from: `src/python/veaf-tools/veaf_libs/data/dcs-schema/`. The
datamined API schema is in this repository, and it decided a question I could not have settled by
reasoning.

### Where it stands

**85 of 140 decided. 55 left**: 28 Error/bug (9 Python, 19 Lua), 9 Documentation, 18
readability/optimization/refactoring to touch only where a file is being changed anyway.

Two findings in `veafSpawnAircraft` were read and deliberately left for the next batch — VMR-098 (AFAC
limit off-by-one) and VMR-099 (an inverted `hiddenOnMFD` flag) both need the surrounding callsign
bookkeeping understood before touching it, and guessing at a spawn limit is how you break a working
feature.

## Sweep, eighth pass — Error/bug, Lua batch 3 (the spawn family), 2026-08-10

The two findings the last batch deferred, plus the four remaining spawn/weather Error/bug entries.
**Six findings; five fixed, one disproved.** Reading the callsign bookkeeping first — the reason
they were deferred — is what showed that half of one finding's remedy was a regression.

| | Outcome | |
|---|---|---|
| VMR-098 | **fixed** | a taken callsign was handed out twice; but the reported `>=` would have capped missions at 7 |
| VMR-099 | **fixed** | `-showmfd` inverted — on **two** handlers, not the one reported |
| VMR-100 | **fixed** | a cargo spawn edited the shared DCS units database |
| VMR-101 | **fixed** | one positionless convoy hid every live one |
| VMR-102 | **fixed** | laser codes no aircraft can dial produced a plausible frequency |
| VMR-103 | does-not-reproduce | proved by enumerating 346 million ordered pairs |

### VMR-098: right about the symptom, wrong about the fix

The finding asked for `>` → `>=` on `numberSpawned > maximumAmount`. Applying it would have broken a
working feature: `numberSpawned` is a **pre-incremented** counter — set to 1 *before* the first spawn
— so `>` already refuses the ninth AFAC, and `>=` would have refused the eighth. Both bounds are now
pinned by tests so the next reader does not have to re-derive it.

The real defect is the other half, and it is a name collision. When the callsign loop found nothing
free it kept its initial value, `callsigns[coalition][numberSpawned].name` — a callsign that may
belong to an AFAC still flying. Two aircraft answer to one name, and the first watchdog to fire
releases a slot the other one is still using. The spawn is now refused instead.

### VMR-099 was two handlers, and VMR-100 was invisible for a good reason

- **VMR-099** — `cap` passes the same raw `options.showMFD` as `afac`, against `not options.showMFD`
  in every other handler. Fixing only the cited line would have left half the defect. The
  consequence is backwards in game: the default hid nothing and `-showmfd` hid the aircraft.
- **VMR-100** — `veafUnits.findDcsUnit` returns the live `dcsUnits.DcsUnitsDatabase` entry, so the
  min/max swap wrote into the shared database. Nothing *observable* changes today, because this is
  the only code that reads `minMass`/`maxMass` besides the `dcsDataExport` dump — worth saying
  plainly rather than dressing it up: the fix is three lines and removes a global write, not a
  reproducible bug.

### VMR-103: disproved by enumeration, with a control

The claim is that the per-component `or` chain is not a chronological comparison. Rather than argue
it, enumerate: 26 304 hour blocks across three years, **345 963 360 ordered pairs**, and the shipped
predicate never once disagreed with a lexicographic `(year, month, day, hour)` comparison. Under a
monotonic clock the two are equivalent — if every component were less-or-equal, the instant could not
be later.

The control is the part that makes the number mean something: the same comparison with the clock
allowed to run backwards **does** diverge. Without it, a probe that enumerates nothing looks
identical to a probe that proves the point. `timer.getAbsTime()` never runs backwards.

### I reintroduced the defect this ticket has now fixed four times

The convoy fix logs a skipped convoy — and I wrote `veaf.loggers.get(...):warning(...)`. The VEAF
logger has `warn`, not `warning`, so the skip path raised. Exactly VMR-077, VMR-078, VMR-081 and
VMR-075: the error path being the error. It was caught by the test rather than by a pilot, which is
the only difference between this and the findings it repeats.

### Two things the measurements turned up that nobody had reported

- **An existing test asserted a wrong behaviour.** `test_returns_string` pinned
  `convertLaserToFreq(1500)` as returning a frequency. `1500` carries two `0` digits and is not a
  dialable DCS code — the test was defending the defect. And two of my own new tests passed before
  the fix, because `1110` and `1101` fall below the 1111 floor and never reached the digit rule;
  replaced with 1210 and 1201, which do.
- **The documentation named the wrong keyword.** Both GUIDE pages show `_spawn afac, … code 1688`.
  `code` is the **TACAN** channel; the laser keyword is `laser`. The example appears to work only
  because `1688` is already the default. Corrected in French and English, with the digit rule written
  down for the first time.

### Where it stands

**91 of 140 decided. 49 left**: 22 Error/bug (**9 Python, 13 Lua**), 9 Documentation, 18
readability/optimization/refactoring the ticket says to touch only where a file is being changed
anyway. No Security flaw, no CONFIRMED finding, and nothing left in `veafSpawnAircraft`.

## Sweep, ninth pass — Error/bug, Lua batch 4 (one defect per module), 2026-08-10

Seven findings across seven modules — six fixed, one disproved. **Two of the seven carried a remedy
that would have made things worse**, which is now the single most repeated observation of this
ticket: the finding is usually right that *something* is wrong and often wrong about *what*.

| | Outcome | |
|---|---|---|
| VMR-085 | **fixed** | a mistyped trigger-zone name crashed every wave, *because* of a deliberate leniency |
| VMR-086 | **fixed** | the remote carrier `start` silently ignored the duration asked for |
| VMR-093 | **fixed** | the SRS position was truncated to whole degrees — up to ~111 km off |
| VMR-094 | **fixed** | operator precedence; the proposed fix would have dropped dynamic slots |
| VMR-095 | **fixed** | `-auth login abc5` raised, and `-auth login -5` unlocked then relocked |
| VMR-096 | **fixed** | the nil dereference was documented by a `@diagnostic disable` and left in |
| VMR-087 | does-not-reproduce | the "unreachable" branch is reachable; the promotion to 6 is what reaches it |

### VMR-094: the remedy was proved wrong rather than argued about

`A or B and C and D` parses as `A or (B and C and D)`, so PLAYER_ENTER_UNIT never reached the name
check and Sanctuary registered a follow entry under the key `""` (the `_unitname or ""` next to it
was quietly absorbing that).

The finding proposes `(A or B) and C and D`. That requires `humanUnits[_unitname]` on
PLAYER_ENTER_UNIT — and `humanUnits` is filled **once**, at `initialize()`, from
`mist.DBs.humansByName`. A **dynamic slot** does not exist then, so Sanctuary would have stopped
following those players altogether: a sanctuary violation with no consequence, which is the opposite
of what the module is for. Rather than reason about it, the proposed remedy was applied and the
dynamic-slot test failed. The two branches genuinely differ, and the fix says so.

### VMR-087: the finding's own evidence contradicts its title

"`_actualDefense > 5` never true after clamp" — but the line above is not a clamp:
`if _actualDefense > 5 then _actualDefense = 6 end` **promotes** to 6, which is exactly what makes
the branch fire (asking for defense 5 and rolling above 80). The two tiers spawn different units, so
this is a working "super" tier. What is left of the finding is that `_addDefenseForGroups` and
`generateAirDefenseGroup` disagree on the ceiling — and removing a difficulty tier is a balance
decision, not a sweep's call.

### VMR-085: the leniency is what made the crash reachable

`setTriggerZone` stores the name *before* checking the zone, and when a centre is already configured
it warns and keeps it — behaviour a test already pinned. So a mission maker who mistypes the zone
name gets a warning at configuration time and a **raise at the first wave**, because `deployWaves`
tested `self.triggerZoneName` rather than the zone itself. It now asks for the zone and then decides,
which is the shape `AirWaveZone:check()` has had all along.

Found while writing the test and deliberately not fixed: `setTriggerZone` writes a **vec2** into
`zoneCenter`, while `setZoneCenter(vec3)` is what the documentation promises. It is harmless today —
that vec2 only exists when the trigger zone does, and then nothing reads `zoneCenter` — so it is
recorded rather than papered over.

### VMR-093 and VMR-095: measuring settled both

- **VMR-093** — `string.format("%d", 41.567)` does not raise in Lua 5.1; it truncates *toward zero*.
  So the SRS broadcast was up to ~111 km from the marker, and wrong in the other direction west of
  Greenwich. I was about to hand-format the number against a locale that might use a comma; testing
  `os.setlocale("French_France.1252")` showed `%.6f` keeps the point. A guard against something I
  could not reproduce is the noise this ticket keeps warning about, so it was dropped.
- **VMR-095** — the guard `not actualMinutes:match("%d+")` is unanchored, so `abc5` passed it and
  `actualMinutes * 60` **raised**: measured, not deduced. `-5` passed too and scheduled the logout in
  the past, so the mission unlocked and relocked without a word. Reachable by any pilot at L1 through
  `-auth login`.

### Where it stands

**98 of 140 decided. 42 left**: 15 Error/bug (**9 Python, 6 Lua**), 9 Documentation, 18
readability/optimization/refactoring to touch only where a file is being changed anyway.

The 6 remaining Lua entries are the ones that need a decision rather than a fix, and they are named
here so the next batch does not have to rediscover it: VMR-073 and VMR-129 are in vendored /
one-shot tooling (`dcs-fiddle-server.lua`, `dictionaryNormalizer.lua`), VMR-130 asks whether to
delete the half-wired `monitoredCommands` eval sink or document it — which belongs with
`REVIEW-SECURITY-LAYER` — and VMR-083, VMR-088 and VMR-089 are contract hardening with no reachable
failure today (the last one says so itself).

## Sweep, tenth pass — Error/bug, Python batch 3 (the conversion and validation chain), 2026-08-10

Five findings, **all confirmed and all fixed** — the first batch in this ticket where nothing was
overstated. What varied instead was *where* the damage lands: three of the five do something worse
than their title claims.

| | Outcome | |
|---|---|---|
| VMR-068 | **fixed** | an ordinary Windows path made `_extract_list` return **nothing**, not less |
| VMR-048 | **fixed** | a statement after the extracted block became a comment — real code lost |
| VMR-051 | **fixed** | an explicit `"lat": null` silently dropped the coordinate |
| VMR-062 | **fixed** | a corrupt mission table reported itself as an *absent* one |
| VMR-050 | **fixed** | by deleting a branch that could only ever have been wrong |

### The three that were worse than reported

- **VMR-068** — `_extract_list` treated any backslash as an escape, ignoring string state, where
  `_extract_table` ten lines above uses an `escape_next` flag honoured only inside a string. A path
  like `"C:\\missions\\"` leaves the closing quote preceded by a backslash, so the string never
  closed and every later brace went uncounted. Measured: **zero** tables returned instead of two, so
  a weather config with a Windows path in it converted to nothing at all.
- **VMR-048** — the title says the *leading* text is corrupted. The head is cosmetic; the tail is
  not. `end` lands just after the table's closing brace, so `} local keep = 1` became
  `-- [v6 extracted…] } local keep = 1` — a live statement turned into a comment.
- **VMR-062** — not silence but a **wrong diagnosis**. The caller already warns when the mission
  table is unavailable; the message says *not found*, which is the one thing guaranteed to send the
  mission maker looking in the wrong place when the file is right there and simply will not parse.

### VMR-050 was fixed by removing code, and the finding offered that option

The collection loop handled a list-shaped trigger category; the removal loop right below calls
`.get()` on the same value, which a list has not. So that branch could only ever raise — and it
could not have been right in any case: **a trigger index is shared across categories**, so mixing
0-based list positions with Lua's 1-based keys would delete other triggers.

The finding's alternative was "drop the list branch if categories are always dicts in practice".
They are, by construction: every read of `mission_content` passes `keep_as_dict=["trig",
"trigrules"]`, and that policy propagates through the subtree. Rather than trust that, it is now
pinned by a test that reads a real `.miz` — with a control asserting a table *outside* `trig` is
still a list, so the invariant test cannot pass vacuously. The half-handling is replaced by an
explicit fail-closed refusal, and a test watches it refuse.

### A test of mine passed for the wrong reason again

The VMR-062 test asserting "an existing file must not be reported as missing" matched only the
English wording — while the default locale here is French, so it passed against the very message it
was written to reject. Both locales are matched now. That is the third batch running in which the
first version of a test proved nothing.

### Where it stands

**103 of 140 decided. 37 left**: 10 Error/bug, 9 Documentation, 18
readability/optimization/refactoring to touch only where a file is being changed anyway.

The 10 Error/bug entries left are the ones that need a decision rather than a fix. Beyond the 6 Lua
ones named above: **VMR-104 and VMR-105 are the publish path** (`veaf_build/github.py`) — tags are
force-pushed before the release exists, so an absent `gh` CLI leaves `published-latest` pointing at a
commit with no release; that is release tooling and deserves its own lot rather than a sweep,
especially with a release in preparation. VMR-053 (`write_miz` leaves its temp file and returns
success on a partial failure) and VMR-061 (bundled JSON trusted without validation) are the
robustness pair and are a natural lot together.

## Sweep, eleventh pass — the Documentation tier, closed, 2026-08-10

**All 9 remaining Documentation findings.** The ticket predicted these were the likeliest to be
already dead, and a third were: three are closed, six were real. **The tier is now closed.**

| | Outcome | |
|---|---|---|
| VMR-120 | already-fixed | closed by the VMR-008 sweep, and now *enforced* by `docs_check` |
| VMR-121 | already-fixed | `convert-other` is in both GUIDE tables |
| VMR-122 | already-fixed | the English twin exists, and the gate requires it |
| VMR-123 | **fixed** | the English page had the See Also links with no heading |
| VMR-124 | **fixed** | the page said `L0` was *public*; in the code it is **ADMIN** |
| VMR-126 | **fixed** | the ASSETS menu is flat; the documented path had a level that does not exist |
| VMR-127 | **fixed** | the pilot permission table matched nothing in the code |
| VMR-139 | **fixed** | two counters, both wrong; deleted rather than refreshed |
| VMR-140 | **fixed** | 8 aliases bypass security, the docs listed 6 |

### VMR-124 is the one that mattered, and it is the same trap twice

The finding says the Mission-Master tier is undocumented. True, but minor next to what the page
actually claimed: **`0 (public) | veafSecurity.LEVEL_L0`**. In the code `LEVEL_L0 = LEVEL_ADMIN = 90`
— the *tightest* tier. `veafSecurity.lua` carries the incident in a comment: someone read "L0 - all
players" off the documentation and would have locked a deliberately public command to administrators.
That was fixed in the mission-maker GUIDE on 2026-08-06 and **left standing on this page**, which is
what a half-finished correction looks like.

Two more traps on the same page, neither reported:

- the key-constants table repeated the inverted meaning (`LEVEL_L0` = "internal weight for public");
- the password example wrote `myAdminPassword` into `password_L9` — the **loosest** tier. A mission
  maker following it would have put the admin password on the tier every listed pilot already passes.

The tier table is now identical to the GUIDE's, which meant giving that section an explicit
`{#security-tiers}` anchor in both languages, per the project's anchor convention.

### VMR-139: the counters were deleted, not refreshed

`TESTING` said 34 suites / ~1000 tests, `ROADMAP` said 31 / ~915, and the tree holds **36**. Both were
wrong, in different directions. Ticket 06 met this family before and dealt with it by deleting the
counters; same here, in all four pages. A number nothing checks is wrong again by the next lot.

### VMR-140: my measurement was wrong before the finding's was

A regex over `VeafAlias:new()` chains reported 7 bypassing aliases and told me `-point` was **not**
among them — so the finding looked half wrong. It was my parse: `-point` is written `VeafAlias` then
`:new()` on the next line, so the chain never matched. Walking every `setBypassSecurity` call back to
its nearest `setName` gives 8, `-point` included. Both aliases the finding named were genuinely
missing from the docs.

That is the fourth time in this ticket that a hand-written pattern under-counted, and the second time
it nearly made me contradict a finding that was right.

### VMR-126 was wider than the path

The ASSETS menu is flat — `addPaginatedRadioElements` gives each asset its own submenu named after
the asset — so the documented *Tankers* / *AWACS* steps do not exist. The labels were wrong too: the
menu is `ASSETS`, in English, in game, and the commands read `Get info on X` / `Respawn X` /
`Dispose of X`. The F10 tree diagram carried the same invented hierarchy **and** put carriers under
ASSETS, when `CARRIER OPS - BLUE/RED` is its own menu.

### Where it stands

**112 of 140 decided. 28 left, and none of them is a fix waiting to be written**: 10 Error/bug that
each need a decision (the publish path VMR-104/105, the robustness pair VMR-053/061, and the 6 Lua
ones named in the previous pass), plus 18 readability / optimization / refactoring the ticket says to
touch only where a file is being changed anyway.

**Both remaining tiers are decision-gated, so the next move on this ticket is David's, not a
sweeper's.**

## Sweep, twelfth pass — the robustness pair, 2026-08-10

**VMR-053 and VMR-061**, the two Error/bug findings that needed no decision from David — the rest of
the tier does. Both confirmed, both fixed, and both misattributed by the review.

| | Outcome | |
|---|---|---|
| VMR-053 | **fixed** | the leak is real; the cause is the aside, not the headline |
| VMR-061 | **fixed** | not merely unvalidated — the two consumers disagreed on the shape |

### VMR-053: the failure was never swallowed, and that made a line unreachable

The finding says a partial failure leaves the original silently unchanged and returns success.
Measured: it does not. `logger.exception` is `error(str(e), exception_type=type(e))`, and
`veaf_libs.logger.error` **raises** — so the failure has always reached the caller. Which means the
line right below it, `temp_zip_path = None`, commented *"prevent replacing the original with a broken
temp file"*, could never run. A guard against a case its own neighbour had already made impossible.

What does reproduce is the leaked temp file, and its cause is the point the finding raises last: the
`NamedTemporaryFile` handle stayed **open** while `zipfile.ZipFile` wrote to that same path. On
Windows `os.unlink` on a file we still hold fails with a sharing violation, and the surrounding
`contextlib.suppress(OSError)` swallowed exactly that — so every failed build left a
`veaf_mission_*.miz` beside the mission.

`mkstemp` + an immediate `os.close` replaces it, with the cleanup moved into a `finally` so it also
covers a failing `os.replace` (which the old code did not). **Proved by putting the open handle
back**: 6 of the 9 tests fail, including one from the *control* group — because `os.replace` cannot
rename an open file either, so the leak was never the only consequence.

### VMR-061: the two consumers did not agree

"No schema validation" undersells it. `lua_config_generator` reads `mod["var_name"]` directly;
`config_migrator` reads `mod.get("var_name")` with a comment explaining that old bundled JSON does
not have it. So a module list that one accepts, the other raises on — which is precisely the
downstream `KeyError` the finding predicts, and it was reachable through the *pre-generated* JSON path
as much as the bundled one.

`get_modules()` now validates what it decoded — a list of tables each carrying a non-empty `id` and
`filename` — and normalises `version` and `var_name`, so both consumers see one shape. Refusals are
localized and name the file at fault, because the reader's next move is to regenerate or reinstall.

### The same TypeError as three passes ago

My first version wrote `t("modules.entry_missing_key", …, key=key)`. `t()`'s own first parameter is
named `key`, so it raised `TypeError: got multiple values for argument 'key'` — the identical mistake
recorded in the CONFIRMED sweep above. Caught by the tests this time as well; the placeholder is
`{field}` now.

### Where it stands

**114 of 140 decided. 26 left, none of them a fix a sweep may write**: 18
readability / optimization / refactoring the ticket reserves for files being changed anyway, and 8
Error/bug that each need a decision — VMR-104/105 (the publish path, and a release is in preparation),
VMR-073 and VMR-129 (vendored / one-shot tooling), VMR-130 (delete the half-wired `monitoredCommands`
eval sink or document it — `REVIEW-SECURITY-LAYER`'s call), and VMR-083 / VMR-088 / VMR-089 (contract
hardening with no reachable failure today).

## Sweep, thirteenth pass — the Error/bug tier closed, 2026-08-11

**The last 8 Error/bug findings, all decided by David** rather than by a sweep, since each needed a
call rather than a fix. **The tier is closed: 122 of 140 decided, and nothing that remains is a bug.**

| | Outcome | |
|---|---|---|
| VMR-104 | **fixed** | tags reached the remote before the release existed |
| VMR-105 | **fixed** | with 104; its "swallowed failures" half does not reproduce |
| VMR-073 | **fixed** | every request errored, and the branch the finding names was unreachable |
| VMR-129 | **wontfix** | legacy one-shot tool, deleted rather than repaired |
| VMR-130 | **fixed** | the SLMOD bridge's remains, deleted |
| VMR-083 | **wontfix** | `veaf.serialize` has three call sites, all debug traces |
| VMR-088 | decided-deferred | one instance of a 794-site family → `REFACTOR-MARKER-PARSER` |
| VMR-089 | decided-deferred | contract hardening the finding itself calls unreachable |

### VMR-130: the history is what made the decision easy

`monitoredCommands` was filled by `veafRemote.monitorWithSlMod(command, script, …)` — the
mission-facing half of the **SLMOD** bridge. That API was deleted on **2021-08-24** (`067495be`,
*"removed slmod monitoring altogether"*, 103 lines), and it left behind a table nothing could fill, a
consumer that could only ever warn, and a `mist.utils.dostring` of arbitrary Lua gated by a password
that ships in a public repository. Four years of a loaded gun with no trigger attached.

Deleted: `executeRemoteCommand`, `markTextAnalysis`, the `_remote` marker entry point,
`monitoredCommands`, `CommandStarter`, the two orphaned `USE_SLMOD*` flags, and the `veafShortcuts`
branch that routed markers there. Nothing to document, because `_remote` was documented nowhere —
which is itself telling.

### VMR-104: the ordering was the bug, and the tests pin the order

`publish` pushed tags first, created the release second. So an unusable `gh` left `published-v<x>` on
the remote with no release, and for a full release **`published-latest` force-moved onto that same
commit** — the tag the updater and every "latest" link resolve. Now `gh` is checked before anything
reaches the remote, and the floating tag moves only after the release exists.

Worth recording: the "swallowed local failures" of VMR-105 does not reproduce. `logger.error` raises
`typer.Abort`, so a failed push or release creation already aborted the publish — and that is exactly
what keeps the floating tag where it was. One test asserts both properties together.

### VMR-073 was unreachable where the finding pointed

`handle_client_connection` returns **nothing**, so `success` was always nil: the failure branch
concatenated a nil and raised on *every* request, and the `clients[id]` branch the finding names
could never run. The response is sent before any of it, which is why the smoke harness worked while
its server errored each time.

### What David decided not to fix, and why it is the right call

- **VMR-083** — measured before deciding: `veaf.serialize` has three call sites in the whole tree and
  all three are debug traces. Nothing reloads its output as Lua, which is the finding's entire
  argument.
- **VMR-088** — the logging refactor he remembered is real and it works (`Logger:trace` checks the
  level before formatting; `veaf.lp` defers serialisation through `__tostring`, 726 uses). This site
  defeats both by pre-formatting *and* by calling a DCS API to build its argument — and there are
  **794** pre-formatted trace/debug calls left in `src/scripts/veaf/`. That is a lot, not a finding.

### Where it stands

**122 of 140 decided. 18 left, and not one of them is a bug**: 9 Readability, 5 Optimization, 4
Refactoring. This ticket's own policy — *"No file is touched purely for readability unless something
else was being changed in it"* — reserves them for `REFACTOR-MARKER-PARSER`, which rewrites exactly
those files and will absorb VMR-088 with them.

**Ticket 04 closes with this pass** (its remaining item was the network download cap) and **ticket 01
has nothing left of its own**.
