# 02 — The runner: launch, load, assert, quit

Status: 🔄 in-progress
Type: feat
Files: `veaf_build/` or a new `veaf-tools` machine-only command, `test/python/`

Depends on: 01

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

- [ ] Command implemented, registered as machine-only.
- [ ] No-DCS path skips with an explanation and exit 0; tested without touching a real install.
- [ ] Bridge readiness polled, not slept.
- [ ] Mission-load freeze handled explicitly, with the reason in a comment citing the measurement.
- [ ] Assertion list is data; the driver knows nothing about individual checks.
- [ ] Every wait bounded, each timeout naming its step; DCS always terminated.
- [ ] Docs: how to run it, what it needs installed, what the exit codes mean.

## Acceptance criteria

- [ ] A full unattended run against a real DCS: launch → load → assert → quit, no human input.
- [ ] Forced-failure run exits non-zero and still leaves no DCS process behind.
- [ ] `ruff` / `mypy` / `pytest` green over the whole tree. The unit tests cover the driver's logic
      with a faked bridge — the real-DCS part is the thing being built and cannot self-test.
