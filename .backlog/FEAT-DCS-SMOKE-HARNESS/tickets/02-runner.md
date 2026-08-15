# 02 — The runner: launch, load, assert, quit

Status: 🧑 waiting-human
Type: feat
Files: `veaf_build/` or a new `veaf-tools` machine-only command, `test/python/`

Depends on: 01

## The lifecycle is written — 2026-08-15

The remainder deferred below (locate, launch, load, quit) shipped as `veaf_libs/dcs_lifecycle.py`
and the `smoke-test --full --mission <miz>` mode, on the facts the probe had already measured:
`net.load_mission` present and `isServer=true` in single-player (so the SERVER-ONLY call is
legitimate on a local instance — option 1 of "the decision step 4 now needs"), `exitProcess`
present. It launches DCS, polls the hook until it answers (the ~28 Hz-at-the-menu measurement is
what makes this a poll, not a fixed sleep), loads the mission, waits on the mission **name** rather
than a frame counter (which freezes during the blocking load), runs the checks, and **always**
quits a DCS it launched — killing it if `exitProcess` does not take. It **refuses** a
already-running DCS by default (loading a mission would overwrite a live session) and does not quit
one it did not start. The orchestration is unit-tested with injected fakes
(`test/python/veaf_libs/test_dcs_lifecycle.py`); the real behaviour of the DCS calls themselves is
what one in-game run confirms, which is why this ticket is waiting-human rather than done.

## Delivered 2026-08-05, and what was cut

**In**: `veaf_libs/dcs_fiddle_client.py` (the transport, both environments, read out of the hook
script rather than assumed), `probe()` reporting what a running DCS actually allows,
`veaf_libs/dcs_smoke.py` with assertions as **data**, and `veaf-tools smoke-test`
(machine-only, `--probe-only`). Skips with an explanation and exit 0 when there is no hook or no
mission — the path that had to work on a machine without DCS, and the only one that could be
exercised here.

**Cut, deliberately**: steps 1, 3, 4 and 6 below — locating DCS, launching it, loading the
mission, quitting. They rest on `net.load_mission` and `DCS.exitProcess`, which this repository
has never called and which no DCS was available to try. Writing that blind is how you ship
plausible code that does not work; `--probe-only` now answers whether those two functions exist,
so whoever finishes this starts from a fact.

## 2026-08-06 — the facts were on disk, and three of them change the plan

Before writing step 3 or 4, ED's own documentation was read: **`<install>/API/Sim_ControlAPI.md`**,
which ships with every DCS and documents the hook API this ticket depends on. It was never opened while
the first slice was written. Three of its statements contradict what the code assumed:

| Assumed | Documented | What it costs |
|---|---|---|
| the control table is `DCS.*` | it is **`Sim.*`**; `DCS` still answers (the fiddle hook calls it and works) | the probe tested `DCS.exitProcess` only, so a DCS that had dropped the alias would have been reported as *unable to quit* rather than as *renamed* |
| `net.load_mission` loads a mission | **SERVER ONLY** | step 4 is now a design decision, not an implementation detail — see below |
| `net.dostring_in` is available | **OBSOLETE and UNSAFE**, permitted only for the states listed in `Config/autoexec.cfg` | **every** assertion rides on it, and David's `autoexec.cfg` lists neither key — so the six checks may have no transport at all on the machine that has DCS |

That last one is the expensive one, and it was **misdiagnosed by construction**: the probe reported an
unreachable mission environment as `no mission loaded?`, so the reader would have gone looking for a
mission to load where loading one cannot help. Fixed: the diagnosis now orders root cause before
symptom — no hook, then no permission, then no mission — and `Capabilities.blocking_reason()` names the
one thing to fix first.

**The probe now measures in one round trip** what previously took four half-answers: which control
table answers and whether `Sim`/`DCS` are the same table, `exitProcess` / `stopMission` /
`setUserCallbacks`, `net.load_mission` **and** `isServer()` together (presence is necessary and not
sufficient), `net.dostring_in`, and — asked rather than guessed, because this workstation carries six
`Saved Games` folders — `lfs.writedir()` and `lfs.currentdir()`, so the harness knows which install and
which write directory the live instance is actually using.

Two more documented capabilities are worth using and are not yet:

- **`onMissionLoadBegin` / `onMissionLoadProgress(progress, message)` / `onMissionLoadEnd`**, registered
  through `Sim.setUserCallbacks` from the hook environment — an **event** for "the load finished".
  That retires the watchdog problem this ticket warns about instead of working around it: no frame
  counter to watch, so nothing to be fooled by its freeze during the ~24 s blocking load.
- **`Sim.getLogHistory(from)`** — `dcs.log` readable through the hook, which is what
  `FEAT-CUSTOM-SCRIPT-LOAD-DELAY` needs (its open question is literally "read `dcs.log` after running
  the built Foothold") without parsing a file off disk.

### Measured on David's DCS, 2026-08-06 (main menu, no mission)

```
control table: Sim+DCS (Sim and DCS are the same table)
net.load_mission: present     net.dostring_in: present
exitProcess / stopMission / setUserCallbacks: present
isServer=True, isMultiplayer=False
install dir: c:\jeux\DCS World\     write dir: C:\Users\David\Saved Games\DCS\
```

So: **`Sim` and `DCS` are literally the same table** — either name works, and the doc's rename is an
alias rather than a migration. **`isServer()` is true in single-player**, which makes the SERVER-ONLY
`net.load_mission` legitimate on a local instance: **option 1 below is settled, measured rather than
argued.** And `net.dostring_in` is **present with no `autoexec.cfg` entries at all**, so ED's stated
restriction does not hold as written — the harness checks for the function, not for the config, and the
prerequisite has been removed from the docs where it had been written on the documentation's word alone.

The run also **found a defect the probe existed to find**, which is the argument for having run it
before writing anything: the last line read

```
mission environment answered; theatre=:1: attempt to index global 'env' (a nil value)
```

David named the cause correctly — no mission at the main menu, so no `env`. But the cause is not the
finding. The finding is that **`net.dostring_in` returns a Lua failure as its string result**, HTTP 200
and a `{result=…}` body, so the probe read a crash as an answer. Worse downstream: `veaf-loaded` exists
to notice an empty environment and uses a truthiness test, so it would have gone **green on the very
reply proving nothing ran** — the third truthy-failure in this lot after the sentinels and the submenu
constant. Fixed at the transport, swept in the tests.

That also puts two of the six checks in doubt: if the stringification is literal, `disposition-returns-points`
(expects a number) and `coalition-scoped-submenu-accepted` (expects `True`) cannot pass however correct
their Lua is. Not guessed — the probe now measures what each Lua type becomes after the crossing.

### The second run, with a mission loaded — and this one invalidates all six checks

`Smerch Hunt II` running, pilot in the cockpit, `mission loaded: tempMission` reported. The mission
environment **still** refused, with the same error:

```
mission environment unreachable although 'tempMission' is loaded and net.dostring_in exists
  — the Lua failed in the mission environment: :1: attempt to index global 'env' (a nil value)
```

The intermediate hypothesis was a **permission**: that seeing `net.dostring_in` in the hook state is not
the same as being allowed to target the mission state, so `net.allow_dostring_in = {"mission"}` was
missing. That hypothesis is **wrong**, and the error text is what refutes it: `attempt to index global
'env'` is a Lua *runtime* error raised **inside the target state**. The chunk ran. A refusal does not
execute your code and then complain about a nil global.

So the state is reachable and simply **has no `env`** — because `env=mission` is the **trigger** state,
the one holding `a_do_script` and the `a_*` actions, not the scripting state where `env`, `timer` and the
VEAF scripts live. Two things in this repository already said so and neither was joined up:

- `FEAT-ASSIST-CHECKLISTS` ticket 01 placed `a_cockpit_highlight` "one `net.dostring_in` away" — it was
  describing this exact state.
- The hook's own bootstrap is `net.dostring_in("mission", 'a_do_script("dofile(…)")')`. It reaches the
  scripting state *through* `a_do_script`. The one line of Lua that proves the layout was read while
  writing the transport and its meaning was missed.

**Consequence: every check in the first slice was aimed one state short of the code it asserts about.**
Not one of them could ever have passed, and the reason nobody noticed is the truthy-failure trap above —
they would have come back with error strings, and `veaf-loaded` would have gone green on one.

Fixed by measuring instead of assuming: `SCRIPTING_ROUTES` holds the candidate ways in, the probe tries
each with `return type(env)` and requires the answer to **be** `table`, and the runner sends every check
through whichever worked. `a_do_script` is tried first because it is the path ED documents as current —
the same paragraph that marks `net.dostring_in` obsolete shows `local a, b, c = a_do_script("return
1,2,3")` — and because the hook already proves it works. `net.dostring_in("scripting", …)` is the
fallback, worth trying because ED's own example spells the target `scripting` while the config key that
permits it is spelled `mission`, so the two vocabularies disagree and only a run settles it.

### The decision step 4 now needs

`net.load_mission` being SERVER ONLY leaves three shapes, and this is David's call because the third
changes what the harness can assert:

1. **Local single instance, call it anyway.** ED documents `Sim.isServer()` as true in single-player
   too, which would make it legitimate. Cheapest to settle: the probe already reports both halves.
2. **Dedicated-server mode**, where the call is unambiguously in scope. But the PRD rules
   multiplayer/dedicated out of scope, and a server has no client slot — so the cockpit-side checks
   (the checklists, `Export.lua` argument reads) could never run there.
3. **Mission on the command line**, if DCS accepts one. **Unverified**, and deliberately not asserted
   here — the whole point of this section is that we stopped guessing.

Option 1 is the recommendation, because it is one measurement away and keeps every check runnable —
**and that measurement has now come back positive** (`isServer=True` in single-player, `net.load_mission`
present), so options 2 and 3 are retired unless the call turns out to do nothing when invoked.

### The third run — the route works, and the transport's real contract lands

`dostring_in-scripting` reaches it; `a_do_script` does **not**:

```
route a_do_script: ran but env is '', so this is not the scripting state
route dostring_in-scripting: reaches the scripting state — env is a table
```

So ED's "there is no need for `net.dostring_in` anymore, you can return values from `a_do_script()`
directly" does not hold on this build either: the call runs and returns nothing. That is the **third**
statement in ED's own shipped documentation this session has had to correct by measurement, after the
`Sim`/`DCS` rename (an alias, not a migration) and the `autoexec.cfg` gate. The obsolete API is the only
one that works, so `SCRIPTING_ROUTES` keeps both and the order is now backed by evidence rather than by
the documentation's preference.

And the shape measurement paid for itself immediately:

| Lua returns | Python receives |
|---|---|
| `'x'` | `'x'` |
| `3` | `'3'` — a **string** |
| `true` | `''` — **destroyed** |
| `{1, 2}` | `''` — **destroyed** |

**A check's Lua must return a string, always** (`TRANSPORT_LOSS`, swept over every expectation). Booleans
and tables are indistinguishable from each other and from a chunk that returned nothing, which condemned
two of the six checks:

- `disposition-returns-points` expected a number and got `'10'`. It was reported FAIL while its Lua had
  in fact **succeeded** — the expectation was the defect. Now returns `count:N`, tagged so `count:0`
  ("asked, got nothing") stays distinct from `''` ("the answer was destroyed").
- `coalition-scoped-submenu-accepted` returned `''`, so it could not distinguish "DCS refused" from "the
  reply was destroyed" — **inconclusive on the exact question FEAT-COMBATZONE-MENU-COALITION has waited
  on since July**. Not better than the earlier false pass, only quieter. The verdict is a word now
  (`created` / `refused-nil`), and that question needs one more run.

### What the run actually established

Measured, in a live mission, by the harness rather than by a person:

- **`Disposition` exists and is a table.** `Disposition.getSimpleZones` exists and is a function.
- Called as `getSimpleZones({x=0,y=0,z=0}, 1852, 100, 10)` it **does not raise** and returns a table of
  **10** entries — matching the 10 passed as the fourth argument, so the assumed signature holds.
- `veaf-loaded` and `findspawnpoint-exists` returned `veaf-absent`, which is **correct**: the mission was
  a stock A-10C_2 single mission with no VEAF scripts. The checks behaved exactly as designed.

What this does **not** establish is the claim ADR 0018 actually rests on — that those points avoid
buildings and forests. That still needs a mission anchored near a village, which is ticket 01's artefact.
Recorded in `FEAT-SCENERY-AWARE-SPAWN` ticket 01 so nobody reads "Disposition works" as "the avoidance is
measured".

## 2026-08-15 — validated in game, and the load step does NOT work as assumed

Ran the real `run_unattended` path against a live DCS (secured hook, `allow_running=True`, so
non-destructive — it does not quit). Two findings, and the second is the important one:

1. **The orchestration is correct.** It detected the running DCS, used it without launching a second,
   authenticated through the secured hook, and called `net.load_mission` — every step in order.
2. **`net.load_mission` does not produce an active mission.** Called from the hook environment at the
   main menu with an absolute path (tried both `\\` and `/` separators), it returns **nil** and
   `Sim.getMissionName()` stays empty for 20 s+ — the mission never becomes active. This is exactly the
   risk the "decision step 4" section below flagged: `net.load_mission` is *present* and `isServer()` is
   true, but **presence is not "it works"**. Whether it silently no-ops in single-player or loads to a
   briefing screen that needs a manual "fly" (which would leave `getMissionName` empty until then) is
   **unresolved** and needs more in-game investigation — do not record "it works" either way.

   Consequence: **`--full`'s load step is unproven**. Options, in order of promise: (3) launch DCS with
   the mission on the **command line** (`DCS.exe <mission.miz>`), which the PRD left unverified and is now
   the one to test, since the post-launch `net.load_mission` route does not deliver; or restrict `--full`
   to asserting against a mission the operator has already loaded.

3. **A transport bug found in passing** (its own small fix, wherever the client protocol lives): the
   vendored omltcat fork serialises a **nil** return as `[]` (an empty table), and `exec_lua` rejects
   `[]` as "carries neither result nor error". Any hook call that returns nothing — `net.load_mission`,
   `exitProcess` — trips it. The fix is to read `[]` as a nil result rather than an error.

## Behaviour (original scope, for the remainder)

One command, unattended, exiting non-zero on a failed assertion:

1. **Locate DCS.** No install → print what was looked for and **skip**, exit 0. This runs on machines
   without DCS and must not read as a failure there (`MACHINE_ONLY_COMMANDS` already exists in
   `veaf_tools.app` for commands that only make sense on a real workstation — this belongs there).
2. **Inject the bridge** — `inject-bridge` already does this, including resolving the key. Reuse it;
   do not write a second injector.
3. **Launch DCS** and wait for the hook to answer. This is the step the hook-boundaries measurement
   makes possible: `onSimulationFrame` ticks at the main menu, so the bridge replies **before** any
   mission is loaded. Poll it rather than sleeping a fixed time.
4. **Load the test mission** and wait for `onSimulationStart`. Note from the same measurement: the
   sim-frame counter **freezes during the blocking mission load** (~24 s observed) — a naive
   "no ticks for N seconds means it died" watchdog will fire here. Do not write that watchdog.
5. **Run the assertions** through the bridge, each one a Lua snippet evaluated in the mission
   environment returning JSON.
6. **Quit DCS** and report. Quit even on failure, or the next run finds a running instance.

## Design notes

- **Assertions are data, not code in the runner.** A list of `{name, lua, expect}` so adding a check
  is adding an entry, not editing the driver. Ticket 03 is then only new entries.
- **Timeouts everywhere, generous.** DCS start-up is tens of seconds and varies with the map. Every
  wait needs a ceiling and a message naming which step timed out; a harness that hangs is worse than
  one that fails.
- **Never leave DCS running.** Kill on timeout. A stuck instance holds a licence seat and the next
  run inherits the mess.
- Output has to be readable by a human at a workstation, not just machine-parseable — this is a tool
  someone runs by hand while debugging, not only in a pipeline.

## Tasks

- [x] Command implemented, registered as machine-only. (`smoke-test --full`)
- [x] No-DCS path skips with an explanation and exit 0; tested without touching a real install.
- [x] Bridge readiness polled, not slept.
- [x] Mission-load freeze handled explicitly, with the reason in a comment citing the measurement.
- [x] Assertion list is data; the driver knows nothing about individual checks.
- [x] Every wait bounded, each timeout naming its step; DCS always terminated.
- [x] Docs: how to run it, what it needs installed, what the exit codes mean.

## Acceptance criteria

- [ ] A full unattended run against a real DCS: launch → load → assert → quit, no human input. **(the in-game run left)**
- [ ] Forced-failure run exits non-zero and still leaves no DCS process behind. **(in game)**
- [x] `ruff` / `mypy` / `pytest` green over the whole tree. The unit tests cover the driver's logic
      with a faked bridge — the real-DCS part is the thing being built and cannot self-test.
