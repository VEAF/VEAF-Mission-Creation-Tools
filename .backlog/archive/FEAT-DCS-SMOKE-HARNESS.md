# FEAT-DCS-SMOKE-HARNESS — assert VEAF behaviour inside a real DCS, unattended

Status: ✅ done — 2026-08-15 (all four tickets; unattended single-player load dropped as undocumented, see ticket 02)

> **First slice delivered 2026-08-05, and it stops short of the lot's own Definition of Done.**
> The transport, the probe, the data-driven check runner and the documented contract are in. What is
> **not** in is any evidence: no DCS was available on the machine that wrote this — no install, no
> `Saved Games` — so not one check has actually run. By this lot's own DoD ("at least one of the four
> pending checks is answered by it, not by a person") that means a framework and no evidence, which is
> exactly the failure mode ticket 03 was written to prevent. The next step is one command on a machine
> with DCS: `veaf-tools smoke-test --probe-only`.
>
> Two things were also deliberately cut from this slice, not forgotten: **launching and quitting DCS**
> (the DCS-side calls have never been made here, so the probe reports whether they exist rather than
> code being written blind against them), and **the committed test mission** (the contract is written,
> the artefact is not).
>
> **2026-08-06, on the machine that has DCS**: the probe was enriched instead of the lifecycle being
> written, because **ED's own API documentation ships with DCS** — `<install>/API/Sim_ControlAPI.md` —
> and had never been opened. It contradicts three of this lot's assumptions: the control table is
> `Sim.*` and not `DCS.*`, `net.load_mission` is **SERVER ONLY**, and `net.dostring_in` — the only
> transport every assertion uses — is **obsolete and gated behind `autoexec.cfg`**, which David's
> install does not enable. So the six checks may have had no transport at all, and the probe would have
> blamed a missing mission. Details and the resulting decision — "the decision step 4 now needs" — in
> ticket 02. No anchor on purpose: the gate does not validate anchors outside
> `doc/`, so linking one would be a link nothing here can check. Nothing was launched either: starting
> DCS is David's to do on his own session.
>
> **The evidence clause of the Definition of Done is met.** Two of the four pending checks are now
> answered **by the harness and not by a person**: `Disposition` exists and `getSimpleZones` returns
> points (`FEAT-SCENERY-AWARE-SPAWN` ticket 01, the singleton half), and **DCS accepts a coalition-scoped
> submenu under a global parent** — which closes `FEAT-COMBATZONE-MENU-COALITION`, open since July. So this
> lot is no longer "a framework and no evidence". Getting there took four runs and cost three of the
> harness's own defects, every one of them a variant of the same mistake — *in this transport, "it came
> back" is not "it worked"*: a Lua error returned as a successful string, six checks aimed at the trigger
> state instead of the scripting state, and booleans and tables arriving as `''`. All three were invisible
> to the mocks by construction, which is the argument for this lot existing.

Origin: [`docs/exploration/DCS-SMS-EXPLOIT.md`](../../docs/exploration/DCS-SMS-EXPLOIT.md) §2.

## Problem

`poetry run test-lua` asserts against `test/lua/dcs_mocks.lua` — a DCS we wrote ourselves. It can
only confirm what we already believed. Everything it cannot reach ends up waiting for a human to fly
it, and that queue is currently four items long:

| Blocked on someone flying it | Where |
|---|---|
| Does `Disposition.getSimpleZones` avoid buildings and forests at all? | `FEAT-SCENERY-AWARE-SPAWN` ticket 01 — **the singleton is measured to exist and return points**; the *avoidance* still needs a mission next to a village |
| ~~Does DCS accept a coalition-scoped submenu under a global parent?~~ **answered: yes, 2026-08-06** | `FEAT-COMBATZONE-MENU-COALITION`, now ✅ |
| Does flattening Foothold's staggered script loading break AIEN/CTLD? | `FEAT-CUSTOM-SCRIPT-LOAD-DELAY`'s open question |
| Do the guided checklists work? | `FEAT-ASSIST-CHECKLISTS` — validated **by hand, in flight** |

That last one is the tell: a whole lot was signed off by a person sitting in a cockpit, which is
exactly what a harness automates. And the local situation is worse than it looks — since
`FIX-LUA-RUNNER-VERSION-CHECK`, `test-lua` **refuses to run on David's machine** (no Lua 5.1), so CI
is the only gate there at all.

## What makes it possible, and it is measured

[`DCS-HOOK-ENVIRONMENT-BOUNDARIES.md`](../../docs/exploration/DCS-HOOK-ENVIRONMENT-BOUNDARIES.md)
measured that `onSimulationFrame` fires at ~28 Hz **with no mission loaded** — 2 305 ticks before any
mission existed, verified end to end with `dcs-fiddle-server.lua` answering at the main menu. That
refutes what `dcs-sms` states as established fact about six comparable tools.

Consequence: a hook keeps polling with DCS sitting at the menu, so a script can **launch DCS, tell it
to load the test mission, assert through the bridge, and quit** — no human in the loop.

The pieces already exist: `dcs-fiddle-server.lua` as a `Scripts/Hooks` hook on `127.0.0.1:12081`, and
`veaf-tools inject-bridge` / `capture-map`, which already do exactly this kind of runtime
interrogation — that is how the airbase dumps for seven theatres were collected. **The missing piece
is not capability, it is the harness**: something that drives DCS's lifecycle and turns answers into
pass/fail.

## The constraint that shapes everything: this can never run in CI

GitHub runners have no DCS, no licence, and no GPU. So this is **not** a CI gate and must not be
sold as one. It is a local, opt-in tool run by whoever has a DCS install — which in practice means
David, or anyone doing the map-capture kit's job.

That is not a weakness, it is a scoping decision with consequences: no flaky-CI risk, no secrets, and
it must degrade to a clear "no DCS found, skipped" rather than a failure when run anywhere else.

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | The test mission, and its documented contract — contract page shipped; committed mission `test/veaf-tools/smoke-test-mission/` (Syria anchor, client slot + ground group + combat zone) builds & validates clean; the anchor's event-firing verified in game 2026-08-15 | ✅ |
| 02 | The runner — probe, transport, data-driven checks **and** the launch/load/quit lifecycle (`--full`) shipped; validated in game — unattended single-player load dropped (no documented API; server mode not pursued), so `--full` is end-to-end only in a hosted-server context | ✅ |
| 03 | Port the four pending in-game checks — questions 1 & 2 answered in game 2026-08-15 (Disposition avoidance measured — 0/30 points on scenery in a 369-scenery area — a `disposition-avoids-scenery` regression check added and passing; submenu re-confirmed); ADR 0018 & TUM-EXPLOIT reconciled from "asserted" to measured. 3 & 4 (Foothold log, checklists) left as stated open questions | ✅ |
| 04 | Assert VEAF through the mission bridge, not the hook — transport split shipped; sentinel fixed | ✅ |

## Steal their test-mission contract, especially the counter-example

Their repo documents *which* mission to use and *why*: theatre **Syria**, anchor
**`(-32220, 405386)`** — "empty desert, far from anything, but DCS does process events there".

The valuable half is the counter-example: at `(-50000, -50000)`, over open water, **DCS silently
drops death events**. A harness that spawns its test units somewhere convenient and empty would watch
kills fail to register and conclude the code is broken. That is a day lost to a non-bug, and it is not
deducible — you have to hit it, or be told.

## Out of scope

- Replacing `test-lua`. The mocks stay: they are fast, they run everywhere, and they pin the
  fallback paths. This harness covers what only a real DCS exhibits.
- Testing the Mission Editor. Rejected — [ADR 0017](../../docs/adr/0017-no-live-mission-editor-bridge.md).
- Multiplayer / dedicated-server scenarios. Single local instance first.

## Definition of Done

- One command runs the whole thing unattended and exits non-zero on a failed assertion.
- Run with no DCS present, it **skips with an explanation** rather than failing.
- At least one of the four pending checks above is answered by it, not by a person — otherwise this
  lot has produced a framework and no evidence.
- The test-mission contract is documented with its *why*, including the open-water event-dropping
  trap, so the next person does not relocate the mission and lose a day.

---

## 01 — The test mission, and its documented contract

Status: ✅ done — 2026-08-15 (mission built + committed, anchor events verified in game, contract page shipped)

### Delivered 2026-08-15 — the committed mission

`test/veaf-tools/smoke-test-mission/` is the committed **source folder** (the `.miz` is a reproducible,
gitignored build artefact). Built through the normal pipeline (`prepare --theatre Syria`, then the MCP
`create_combat_zone` for the ground group + trigger zone, `add_player_slot` for the client slot), it
**validates clean** (a real player slot; coalitions set) and **builds clean**. It holds a client A-10C
slot, a two-tank ground group at the anchor, and a `SmokeZone` combat zone. `build.dev_mode` is not
persisted so the fixture stays machine-independent. Its README carries the theatre/anchor rationale.

The **anchor was verified in game** (not taken on trust): a unit spawned at `(-32220, 405386)` on a
`land` surface (~242 m) and blown up produced a death event the harness caught. The open-water
counter-example stays credited to `dcs-sms` in the contract page.
Type: feat
Files: a committed test `.miz` (or its `mission.yaml` + build recipe), `docs/` contract page

### Why the contract matters more than the mission

Anyone can make an empty mission. The part that is hard to reacquire is **where to put it and why**,
and `dcs-sms` documents theirs: theatre **Syria**, anchor **`(-32220, 405386)`**, described as "empty
desert, far from anything, but DCS does process events there".

The counter-example is the whole point: at **`(-50000, -50000)`**, over open water, **DCS silently
drops death events**. A harness whose units die without the engine reporting it produces confident
false failures. Nobody deduces that; you lose a day to it or you are told.

So this ticket's deliverable is half artefact, half written rationale — and the rationale is the half
that must not be skipped.

### The mission

- [ ] Built from a committed `mission.yaml` through the normal pipeline rather than hand-made in the
      editor, so it is reproducible and so it exercises the toolchain on the way in.
- [ ] Theatre and anchor chosen and **justified in writing**. Take Syria + their anchor unless there
      is a reason not to; if a different theatre is needed (a WWII check, say), state the anchor for
      that one too and verify events fire there.
- [ ] Minimal but not empty: a human-playable slot (a mission with no client slot behaves
      differently), a small ground group, a trigger zone, and whatever the first assertions need.
- [ ] The VEAF scripts injected the normal way, so what runs is what ships.

### Delivered 2026-08-05: the contract page

`doc/developer/smoke-harness.{md,en.md}`, both languages, in the mkdocs nav. It carries the
theatre, the anchor, and the open-water counter-example as the stated reason — plus an explicit
warning that **these coordinates are not verified here**, credited to dcs-sms, with the note that
this repo has already found two claims in their docs to be false.

**Outstanding**: the mission artefact itself, and killing a unit at that anchor to watch the
event arrive. Both need a DCS install.

### The contract page

- [ ] Theatre, anchor, and **why that anchor** — including the open-water event-dropping trap as the
      stated reason, credited to the dcs-sms study.
- [ ] What the mission contains and what may be added without invalidating existing assertions.
- [ ] How to run it, and what "no DCS installed" looks like.
- [ ] Verify, in game, that events actually fire at the chosen anchor — kill a unit, watch the event
      arrive. **Do not take their coordinates on trust**: this repo has twice found claims in that
      project's docs to be false (the hook/editor VM claim, the "dies at the main menu" claim).

### Acceptance criteria

- [ ] The mission builds from its `mission.yaml` with `validate` + `build` clean.
- [ ] A death event observed at the chosen anchor, in game, and the observation recorded.
- [ ] The contract page passes `docs-check` (links, anchors, both languages if it is user-facing).

---

## 02 — The runner: launch, load, assert, quit

Status: ✅ done — 2026-08-15 (runner shipped; unattended single-player load dropped, David's call)
Type: feat
Files: `veaf_build/` or a new `veaf-tools` machine-only command, `test/python/`

Depends on: 01

### The lifecycle is written — 2026-08-15

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

### Delivered 2026-08-05, and what was cut

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

### 2026-08-06 — the facts were on disk, and three of them change the plan

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

#### Measured on David's DCS, 2026-08-06 (main menu, no mission)

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

#### The second run, with a mission loaded — and this one invalidates all six checks

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

#### The decision step 4 now needs

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

#### The third run — the route works, and the transport's real contract lands

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

#### What the run actually established

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

### 2026-08-15 — validated in game, and the load step does NOT work as assumed

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

#### What shipped in response (same PR)

- **The `[]` bug is fixed**: `exec_lua` reads an empty-table reply as a nil result. Test added.
- **The SP load limitation is documented, not papered over**: `_load_mission`'s docstring, the
  `_wait_for_mission` timeout message, the harness docs (both languages) and the CHANGELOG all state
  that `net.load_mission` loads nothing in single-player and that `--full` therefore fails cleanly
  there rather than lying — with the workaround (load by hand, `smoke-test` without `--full`).
#### Unattended single-player load — dropped, David's call 2026-08-15

Verified against ED's shipped API (`<install>/API/Sim_ControlAPI.md`): **there is no documented way to
load a mission in single-player.** `net.load_mission` is SERVER ONLY (it overrides a *server's* mission
list, so it no-ops without a hosting server), `Sim.*` has no load function at all, and there is no
mission command-line argument (the earlier "option 3" was speculative — scrapped). The *only* documented
path is **server mode**: launch DCS as a hosted server reading `Config/serverSettings.lua`, which loads
`missionList[listStartIndex]` on startup; the harness's scripting-env checks run there because they do
not need a client cockpit.

David weighed value against effort and **dropped unattended single-player load**: the server-mode
chantier is not worth it now, and the interactive path already works — load the mission by hand, then
`smoke-test` (without `--full`) asserts against it. So:

- `--full` (launch → `net.load_mission` → wait → assert → quit) **ships as-is**. It is end-to-end only
  where a mission can actually load (a hosted-server context); in single-player it fails cleanly at the
  load timeout saying so. That behaviour is intended, not a bug to fix.
- Unattended single-player load is **wontfix** — the documented API does not allow it, and server mode
  is deliberately not pursued. If a future need arises, server mode (patch `serverSettings.lua` + launch
  `--server`) is the recorded path.

The runner is delivered; this ticket is **done**.

### Behaviour (original scope, for the remainder)

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

### Design notes

- **Assertions are data, not code in the runner.** A list of `{name, lua, expect}` so adding a check
  is adding an entry, not editing the driver. Ticket 03 is then only new entries.
- **Timeouts everywhere, generous.** DCS start-up is tens of seconds and varies with the map. Every
  wait needs a ceiling and a message naming which step timed out; a harness that hangs is worse than
  one that fails.
- **Never leave DCS running.** Kill on timeout. A stuck instance holds a licence seat and the next
  run inherits the mess.
- Output has to be readable by a human at a workstation, not just machine-parseable — this is a tool
  someone runs by hand while debugging, not only in a pipeline.

### Tasks

- [x] Command implemented, registered as machine-only. (`smoke-test --full`)
- [x] No-DCS path skips with an explanation and exit 0; tested without touching a real install.
- [x] Bridge readiness polled, not slept.
- [x] Mission-load freeze handled explicitly, with the reason in a comment citing the measurement.
- [x] Assertion list is data; the driver knows nothing about individual checks.
- [x] Every wait bounded, each timeout naming its step; DCS always terminated.
- [x] Docs: how to run it, what it needs installed, what the exit codes mean.

### Acceptance criteria

- [ ] A full unattended run against a real DCS: launch → load → assert → quit, no human input. **(the in-game run left)**
- [ ] Forced-failure run exits non-zero and still leaves no DCS process behind. **(in game)**
- [x] `ruff` / `mypy` / `pytest` green over the whole tree. The unit tests cover the driver's logic
      with a faked bridge — the real-DCS part is the thing being built and cannot self-test.

---

## 03 — Port the four pending in-game checks

Status: ✅ done — 2026-08-15 (questions 1 & 2 answered in game; 3 & 4 left as stated open questions)
Type: feat
Files: the assertion list from 02, plus status updates on the four lots

Depends on: 02

### Why this ticket is the point of the lot

A harness with no assertions is a framework, not evidence. These four are already written down as
open questions on real lots, and each is currently waiting for a person:

**1. `Disposition` — `FEAT-SCENERY-AWARE-SPAWN` ticket 01 (🧑)**
The richest one, and the reason that lot is not closed. Assertions: does the singleton exist; what is
its exact signature; do the points it returns actually avoid buildings and forests when centred on a
village and on a forest; what does it return centred on dense city with a small radius (the fallback
branch depends on the answer); is it present on a WWII map; what does one call cost.
Outcome either closes ticket 01 or deletes tier 1 of `veaf.findSpawnPoint` — and ADR 0018 stops
saying "asserted, not measured".

**2. Coalition-scoped submenus — `FEAT-COMBATZONE-MENU-COALITION` (🧑 since July)**
Does DCS accept `addSubMenuForCoalition` **under a global parent**? The unit tests pin which API is
called with which arguments; they cannot pin DCS's reaction. A negative answer has a known fallback
(scope the `COMBAT ZONES` parent too), so this is a decision waiting on one fact.

**3. Staggered script loading — `FEAT-CUSTOM-SCRIPT-LOAD-DELAY`'s open question**
Upstream Foothold loads in four waves, the last at 12 s; our build fires all fourteen scripts in one
`triggerStart`. Assertion: load the built Foothold and check `dcs.log` for AIEN / CTLD initialisation
errors. Nothing broken → the lot is a fidelity nicety; something broken → it is a correctness bug for
every adopted mission and jumps the queue.

**4. Guided checklists — `FEAT-ASSIST-CHECKLISTS`**
Already validated, but **by hand, in flight**. Porting even a subset turns a one-off human sign-off
into a regression guard, which matters because that engine reads live cockpit state through
`net.dostring_in` and a DCS patch could break it silently.

### Written 2026-08-05, none of them run

Six checks in `CHECKS`, covering two of the four questions:

- **`Disposition`** (3 checks): does the singleton exist, does `getSimpleZones` exist, and what
  does it return when called. The avoidance itself is not among them — that needs a mission
  placed beside a village, which is ticket 01's outstanding half.
- **Coalition-scoped submenu** (1 check): does DCS accept `addSubMenuForCoalition` under a global
  parent. This is the whole of what `FEAT-COMBATZONE-MENU-COALITION` has been waiting on.
- **Two sanity checks**: that `veaf` and `veaf.findSpawnPoint` are actually loaded, so a stale
  script bundle cannot make every other check vacuously pass.

Writing them surfaced a bug worth recording: the snippets return truthy **sentinel strings**
(`veaf-absent`, `no-singleton`) rather than raising, so an expectation written as a plain
truthiness test passed in exactly the case it existed to catch. A test now sweeps every check
against every sentinel.

**Not done: running them.** Foothold's staggered loading and the guided checklists have no checks
yet either.

### Run in game — 2026-08-15 (Syria)

Questions 1 and 2 are **answered by the harness**, and the `[]`-drift the ticket body warned about is
resolved:

- **Question 1 — `Disposition`.** Signature measured: `getSimpleZones(centre_vec3, radius_m, arg3, count)`
  → array of `{x, y, course}` 2D points. **Avoidance measured**: centred on the airbase Abu al-Duhur
  (369 scenery objects within 2 km), all 30 returned points were 0 within 10 m of scenery and all on a
  `land` surface. It **returns fewer than requested when clear space is scarce** (150 m → 2, 500 m → 10,
  2000 m/req 50 → 50; desert → 30), so tier 1's fallback is necessary. Cost ~43 ms/call. `arg3` and
  WWII-map presence remain unmeasured. A new **regression check `disposition-avoids-scenery`** encodes
  this (0 of 30 near scenery in a scenery-bearing area) and **passes live**. Note: `FEAT-SCENERY-AWARE-SPAWN`
  had already run its probe on 2026-08-06 (it is archived ✅), but ADR 0018 and TUM-EXPLOIT.md were left
  saying "asserted, not measured" — today reconciles that stale wording with the measurement and adds the
  harness **regression check** the archived probe never left behind.
- **Question 2 — coalition-scoped submenu.** Re-confirmed live (`created`); `FEAT-COMBATZONE-MENU-COALITION`
  was already closed on this.

### Tasks

- [x] Assertions added for 1 and 2 — the two lots actually blocked. (`disposition-avoids-scenery` added;
      the submenu check already existed.)
- [x] `Disposition` probe covers the load-bearing questions — existence, signature, avoidance, short-count
      fallback, cost. (`arg3` meaning and WWII-map presence explicitly left unmeasured.)
- [x] Run them; measurements written into `docs/exploration/TUM-EXPLOIT.md`.
- [x] Update ADR 0018 from "asserted" to measured.
- [x] Reconcile the stale docs — `FEAT-SCENERY-AWARE-SPAWN` was already ✅ (probe 2026-08-06), but
      ADR 0018 / TUM-EXPLOIT still said "asserted"; now measured, with a regression check.
- [ ] 3 (Foothold staggered loading, read `dcs.log`) and 4 (checklists as a regression check) — **not
      done today**; left as open questions rather than pretended covered. Both need a specific mission
      loaded (built Foothold; an assisted cockpit) — a follow-up session.

### Acceptance criteria

- [x] At least the `Disposition` question is answered **by the harness**, not by a person.
- [x] Every measurement recorded in the exploration note and the ADR, not only in a PR description.
- [x] No lot left claiming a status the facts contradict.

---

## 04 — Assert VEAF through the mission bridge, not the hook

Status: ✅ done 2026-08-15 — transport split shipped: VEAF checks ride the mission bridge, DCS-native
checks the hook; the `env`-based sentinel is replaced by a measured `type(veaf)` probe; a bridge-absent
VEAF check fails naming `dcs-serve`. The two side findings below (rebuild the test mission, restore
mutating checks from source) are notes for tickets 01/03, not code in this one.
Type: fix

### What the 2026-08-09 run measured

Run against a live DCS with a VEAF mission in flight, the harness reported:

```
[FAIL] veaf-loaded: returned 'veaf-absent'
[FAIL] findspawnpoint-exists: returned 'veaf-absent'
```

while three `Disposition` checks passed and `coalition-scoped-submenu-accepted` returned
`created`. `dcs.log` showed the scripts loading normally (`STATIC VEAF scripts loading`, then
`VEAF-GROUNDAI`, `VEAF-COMMANDS`, `VEAF-RADIO` initialising). So `veaf-absent` was **not** a
mission problem.

The pattern explains itself once you sort the globals by who creates them:

| Global | Created by | Seen by the hook route |
|---|---|---|
| `env`, `Disposition` | DCS itself | **yes** |
| `veaf`, `veafRadio`, `veafSecurity` | the mission's scripts | **no** |

The route reaches a scripting state that never ran the mission's scripts. `dcs.log` agrees:
`Error while executing string in scripting` for probes as trivial as `return true`.

#### Re-measured 2026-08-15, on a different mission, same verdict

Run again against `TestMenuFR-fixed.miz`: same two failures, same four passes. Probing the route's
globals directly adds three details that close the door on any remaining doubt:

- `env.mission.theatre` returns `Caucasus` — so the route **is** in a state that can read the loaded
  mission, which is what made `env`-based detection look convincing;
- `veaf` is `nil`, **and so is `mist`** — not one of the **1683** globals in that state contains the
  string "veaf", in any case;
- `missionCommands`, `trigger` and `coalition` are all tables, which is why the DCS-native checks keep
  passing and why 4/6 reads as "mostly working".

Nothing here is new — the ticket had it right on 2026-08-09. It is recorded because a second
independent measurement on another mission removes "maybe that run was odd" as an explanation, and
because **running the harness again cannot produce anything else until this ticket lands**. That is the
useful conclusion for whoever is tempted to spend a DCS session on it.

### The route that does work, proven the same day

`dcs-bridge.lua` is injected **into the mission** at build time (it is the trigger whose index
shift VMR-005 fixed), so it lives in the state where `veaf` exists. With `dcs-serve` running:

```
capabilities -> veaf version 6.13.2, mist 4.5.128-DYNSLOTS-02-VEAF
exec_lua "return type(veaf) .. '|' .. tostring(veaf.Id) .. '|radio=' .. type(veafRadio)"
      -> "table|VEAF|radio=table|security=table"
```

**`veaf` is reachable.** The harness's limitation is a transport choice, not a property of DCS.

### Why the harness picked the hook, and where that generalised too far

`dcs_fiddle_client`'s own docstring gets it right: `onSimulationFrame` answers **with no mission
loaded**, and a bridge living inside a mission cannot be what loads that mission. Sound — *for the
load step*. But the module calls itself "the harness's single transport", and the argument for one
step became the rule for all of them.

The two needs have different constraints:

| Need | When | Transport |
|---|---|---|
| locate, launch, load, quit | before / outside a mission | **fiddle hook** — the only one that answers |
| assert VEAF behaviour | mission in flight | **dcs-bridge** — the only one that sees `veaf` |

### Tasks

- [x] Split the transport: `Check.transport` is `hook` or `bridge`; `veaf-loaded` and
      `findspawnpoint-exists` ride the bridge (`veaf_libs.dcs_bridge_capture.exec_over_bridge`), the
      DCS-native checks keep the hook. `run()` resolves the bridge once, only when a VEAF check needs it.
- [x] Fix the sentinel: `probe()` now measures `type(veaf)` on the hook route and records
      `hook_sees_veaf`, and the route note no longer claims the mission's scripts ran because `env` is a
      table. This was the **fourth** truthy-failure in the lot.
- [x] Bridge is a stated prerequisite: a VEAF check with no reachable bridge (or no API key) **fails
      naming `dcs-serve`** (`smoke.bridge.unreachable` / `smoke.bridge.no_key`), never `veaf-absent`.
      `smoke-test` gained `--serve-url`, `--api-key`, `--config`. Documented in `smoke-harness.md`
      (both languages).

### A second finding from the same run: the test mission must be built, not stored

`findspawnpoint-exists` also returned `veaf-absent`, and that one is **not** the transport:
`exec_lua` through the working route confirms `veaf.findSpawnPoint` is genuinely nil in that
mission. The reason is the mission's age — it carries veaf **6.13.2**, built 2026-08-02, and
`findSpawnPoint` first appears on **2026-08-05** (`4f15f228`, FEAT-SCENERY-AWARE-SPAWN).

So a stored `.miz` silently tests whatever VEAF version it was built with. The lot's existing
"committed test mission" item therefore needs one more clause: the mission is **rebuilt from
source before the run**, or the harness asserts against a snapshot of the past and calls today's
code broken.

### The transport was exercised end to end on 2026-08-09, after this ticket was written

A mission built from current sources (`veaf.BuildVersion = 6.13.47+4a6d7cbc` — the build stamp
identifies the commit, so there is no doubt about what ran) with `dcs_bridge.enabled: true`, then
driven entirely over that bridge. What it answered, none of which the hook transport can reach:

| Asserted live | Result |
|---------------|--------|
| `veaf`, `veafSecurity`, `veafRemote` loaded | tables, not `veaf-absent` |
| `veaf.findSpawnPoint` over open water | `nil` — refuses rather than inventing a point |
| `findSpawnPoint` with an absurd clearance in a 100 m radius | 95 m — tier 2 degrades, **radius still honoured** |
| group of a level-10 and a level-1 pilot | acts at **1**, the minimum |
| the level-10 occupant elevates | 10 |
| the level-1 occupant elevates | **1** — cannot borrow the other's rights |
| a pilot with no level elevates | refused, group falls back to its minimum |
| an elevation past its deadline | dropped from the table, level falls back |

So the transport question is settled by measurement, not argument: `dcs_bridge` reaches the state
the mission's scripts run in, and everything this lot wants to assert is reachable from it.

#### One trap, paid for during the run

A probe crashed midway, **leaving a stubbed `getGroupOccupantUnitNames` behind**. The next probe
saved-and-restored that stub believing it was the real function, and the fallback silently read 1
instead of 0. The result looked plausible, which is exactly why it was nearly missed — the same
*"it came back is not it worked"* mistake this lot has now made four times.

For the harness this is a requirement, not an anecdote: **a check that mutates mission state must
restore from the source, never from what it found there**, because what it found may be the wreckage
of an earlier failed check. A crashed probe leaves the state dirty for every probe after it.
