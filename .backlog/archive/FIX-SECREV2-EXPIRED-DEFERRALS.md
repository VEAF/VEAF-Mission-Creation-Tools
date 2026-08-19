# FIX-SECREV2-EXPIRED-DEFERRALS — two deferred findings whose condition came due

Status: ✅ done — 2026-08-15 (ticket 01 delivered #717; ticket 02 adopts the omltcat fork, auth on / bypass off, validated in game)

## Why this lot exists

`SECREV-2` closed on 2026-08-11 with all 140 findings decided. Twenty-one are `decided-deferred`, and
**a deferral is only honest if something eventually collects it.** Two of the six older ones were
deferred *against a named condition*, and both conditions have now moved:

- **VMR-088** was deferred *"to `REFACTOR-MARKER-PARSER`, on David's call, because it is one instance of
  a family"*. **That lot closed the same day without touching it** — `veafCombatMission.lua` is not one
  of the marker parsers it migrated. So it is now deferred to a lot that no longer exists.
- **VMR-013** keeps the fiddle-server port unauthenticated *"because no DCS is available to test a change
  to the transport `FEAT-DCS-SMOKE-HARNESS` speaks through"*. The harness has since run in game, and its
  ticket 04 explicitly **keeps the hook** for driving DCS — so the dependency is real and still live,
  but nothing links the two.

Found while restoring the triage that archiving `SECREV-2` had deleted. Neither is tracked anywhere
else, and both would have gone quiet.

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | Read a unit's life once, not four times | ✅ |
| 02 | The fiddle-server port: re-anchor the deferral or close it | ✅ |

**01 is a small, self-contained correctness fix** and can be done now. **02 needs a DCS session** and is
coupled to `FEAT-DCS-SMOKE-HARNESS` ticket 04, so it is `🧑 waiting-human` — an agent should not pick it
up, and its first job is to decide whether it should exist at all or become a line in the harness ticket.

## What this lot is not

Not the 794-call logging chantier. VMR-088's triage entry measured **794 pre-formatted trace/debug calls
across `src/scripts/veaf/`** and David's verdict was *"that is a lot, not a finding"* — that stands. This
lot fixes the **correctness** half of VMR-088 at its one site, and leaves the family alone.

---

## 01 — Read a unit's life once, not four times

Status: ✅ done
Type: fix
Finding: VMR-088 (Error / bug, LOW), `src/scripts/veaf/veafCombatMission.lua:778`

### What is there

`VeafCombatMission:getRemainingEnemies` calls `veaf.getUnitLifeRelative(unit)` up to **four times per
unit** — measured afterwards: **2 on the alive path, 4 on the damaged one**, since each branch reads
again. The review reported three; nobody had counted:

```lua
:trace(string.format("veaf.getUnitLifeRelative(unit) = %f", veaf.getUnitLifeRelative(unit)))  -- 781
if veaf.getUnitLifeRelative(unit) == 1.0 then                                                 -- 782
elseif veaf.getUnitLifeRelative(unit) > whatsInAKill then                                      -- 785
  :trace(string.format("unit[%s] is damaged (%d %%)", …, veaf.getUnitLifeRelative(unit) * 100)) -- 788
```

### Two problems, and the classification one is the real finding

**A unit can be classified inconsistently.** The value is read fresh for each test, and a unit under
fire changes between reads. So `== 1.0` can be false while the *next* read is back at 1.0, or a unit can
fall past `whatsInAKill` between line 782 and line 785 and land in the `else` — the branch whose own
comment says *"should never come to that"*. The counts feeding
`veaf.t("combatmission.enemies_count", …)` are then wrong, and a mission's remaining-enemies message is
exactly the kind of thing a player trusts without checking.

**And two of the four calls are made for logs that may not be emitted.** `Logger:trace` checks the level
before formatting, and `veaf.lp` defers serialisation through a `__tostring` metatable — 726 uses in the
tree get this right. These sites defeat both: they call `string.format` themselves, and the argument is a
**DCS API call**, so the work happens whatever the log level.

### Tasks

- [x] Read it once into a local, before the branch, and use that local everywhere including the traces.
- [x] A test that a unit whose life changes between reads is still counted exactly once — the point of
      the fix, and the part a reader will want pinned.
- [x] Do **not** widen this to the other 794 pre-formatted calls (see the PRD).

### Acceptance criteria

- [x] One `getUnitLifeRelative` call per unit per pass.
- [x] `nbLiveUnits + nbDamagedUnits + nbDeadUnits` stays consistent with the group's spawned count.
- [x] `poetry run test-lua` green.

### Worth knowing while you are in there

The `else` branch counts nothing at all — it only traces "is dead", on the assumption that dead units do
not come back from `getUnits()`. With one read that assumption becomes checkable rather than racy, so if
you make it reachable, decide deliberately whether it should increment anything.

### Delivered — 2026-08-11

One `local unitLife = veaf.getUnitLifeRelative(unit)` before the branch, used by the test, the threshold
and both traces.

**Measured, before and after**, with a counting stub in place of the DCS call:

| Unit state | Calls before | Calls after |
|---|---:|---:|
| full health | 2 | 1 |
| damaged | **4** | 1 |

So the review's "three" and my own "four" were both partly wrong: it is **two on the alive path and four
on the damaged path**, because each branch reads again. Only measuring gave the real numbers, and the fix
is the same either way.

10 tests. Three were red before the change and are the ones that matter: the call count, a unit reading
1.0 then 0.0, and a unit reading 0.5 then 1.0 — both counted exactly once now, whichever value the single
read returns.

#### A truncated `head` nearly hid one

The first run looked like two failures because I piped the output through `head -12`. There were **three**
— the call-count assertion was the one cut off. Worth recording: a filtered test report is not a test
report, and this session had already been caught by a probe that sampled instead of enumerating.

#### The `else` branch is now reachable, and deliberately counts nothing

Its comment claimed *"should never come to that, Moose do not return dead units in getUnits()"*. With one
read the branch is reachable for a unit at or below `whatsInAKill`, and the correct behaviour is exactly
what it does: increment nothing, and let the group's spawned count turn it into a dead unit below.
Comment rewritten to say that rather than to deny the branch exists. A test pins it
(`test_below_the_kill_threshold_the_unit_is_dead` → `{0, 0, 1}`).

---

## 02 — The fiddle-server port: re-anchor the deferral or close it

Status: ✅ done — 2026-08-15 (validated in game)
Type: chore
Finding: VMR-013 (Security flaw, **MEDIUM**), `src/scripts/other/dcs-fiddle-server.lua:270`

### The finding, and why its own severity understates it

`dcs-fiddle-server` **executes arbitrary Lua from unauthenticated HTTP requests**. No token, no origin
check. [ADR 0019](../../docs/adr/0019-dcs-fiddle-server-stays-unauthenticated-for-now.md) accepted
that, for now, with reasons.

The triage entry adds something the review did not say, and it is the part to carry forward:

> *Severity is understated in the review: `cors='*'` plus a GET channel means **any web page visited
> while the hook is installed gets code execution**, so "loopback only" is not the protection it sounds
> like.*

That is the sentence to re-read before deciding this can wait again.

#### The unauthenticated half is no longer a claim — 2026-08-15

While probing the smoke harness on David's machine, arbitrary Lua was executed against
`127.0.0.1:12081` from an ad-hoc Python script that presented **no credential of any kind**: an
enumeration of all 1683 globals in the scripting state, plus reads of `env.mission.theatre`. It
returned data on the first attempt.

That confirms the finding's first half by doing it. The second half — the one the triage calls
understated — was then settled **by reading the source, not by building an exploit** (David: *"t'as pas
le droit, règles cyber"*, and he is right). `dcs-fiddle-server.lua` shows all three properties in three
lines:

- **line 568**, `if request.method ~= "GET"` — the only accepted verb is **GET**;
- **line 572**, the Lua is read from `request.path`, base64-decoded, and handed to `net.dostring_in` /
  `loadstring` (lines 336/343) — so **the whole payload rides in the URL**;
- **lines 542 / 593-594**, `cors = "*"` echoed into `Access-Control-Allow-Origin` on every response.

No token, origin or `Referer` check anywhere on that path. A GET whose payload is entirely in the URL
is fired by a web page with **no CORS preflight** — a bare tag whose source is the server URL is
enough to run the Lua; the page never needs to read the response, the code has already run inside DCS.
`cors='*'` additionally lets any origin read the result. So "loopback only" is no protection: the
attacker does not reach the port from outside, the **victim's own browser** — which is on the loopback
— makes the request. The review's MEDIUM is understated, now established from the code rather than
argued.

### Why it was deferred, and what has changed

Deferred because *"no DCS is available to test a change to the transport `FEAT-DCS-SMOKE-HARNESS` speaks
through, and shipping untested auth there breaks the harness invisibly."* Two things did ship instead: a
danger warning in the harness documentation, at the point where it tells you to install the hook, and
**the token design, written down in ADR 0019 to be implemented with the harness's remaining slice, where
it can be tested.**

What changed by 2026-08-11: the harness **has** run in a live DCS. What did *not* change: its ticket 04
(*"Assert VEAF through the mission bridge, not the hook"*) explicitly **keeps the hook** for driving DCS —
locate, launch, load, quit — and only moves the `veaf-*` assertions to the mission bridge. So the
dependency is real and still live.

### This ticket's first job is to decide whether it should exist

Three possible outcomes, and picking one is the work:

1. **Fold it into `FEAT-DCS-SMOKE-HARNESS` ticket 04** and delete this ticket. The token was designed to
   land with that slice; if ticket 04 is the slice, this is a duplicate and the honest fix is a paragraph
   there rather than a lot here.
2. **Implement the token now**, if the harness can be exercised in a DCS session — ADR 0019 says the
   design is ready and only the testing was missing.
3. **Re-anchor the deferral to a condition that can actually expire**, if neither is possible today.
   *"When the harness's remaining slice ships"* is such a condition; *"when a DCS is available"* is not,
   because nothing announces it.

Outcome 1 is the most likely and the cheapest. What must **not** happen is a fourth deferral with no
named collector — that is how this finding became invisible for a month in the first place.

### Decision — outcome 2, and the vendored file was the wrong one (2026-08-15)

Going to implement the token surfaced the decisive fact: the repo's `src/scripts/other/dcs-fiddle-server.lua`
is a **stale JonathanTurnock copy that nobody installs**. The hook actually used — and the one the
harness was validated against — is the **omltcat/dcs-lua-runner** fork, which already carries HTTP Basic
auth but ships `BYPASS_LOCAL = true`: loopback requests skip auth via the (spoofable) Host header. **That
is the real VMR-013**, and hardening the stale copy would have fixed nothing on the machine that runs the
fork.

So, on David's call (option A), the repo **adopts the fork**:

- vendor omltcat/dcs-lua-runner as `src/scripts/other/dcs-fiddle-server.lua`, re-applying the VEAF
  `sanitizedModule` patch;
- `AUTH = true`, `BYPASS_LOCAL = false`;
- a **per-session password** generated in the hook environment at launch and written to
  `%USERPROFILE%\dcs-fiddle-token.txt` (fixed path, since a workstation carries several write dirs and
  only the running DCS knows which is live); the mission environment reads the same file so both ports
  check the same password;
- the harness client reads that file and sends it as HTTP Basic (username `veaf`), with
  `--fiddle-token` / `$DCS_FIDDLE_TOKEN` as the override.

A web page cannot read a local file, so it can no longer authenticate — the exposure is closed. The
condition ADR 0019 named is met and collected, not re-deferred. The **live confirmation** the ADR insists
on is the one thing left: `smoke-test --probe-only` against a DCS running the vendored hook. The Lua half
cannot be unit-tested; the client half is (`test/python/veaf_libs/test_dcs_fiddle_token.py`).

### Tasks

- [x] Read ADR 0019's token design and check it against what the harness actually needs.
- [x] Pick an outcome and write the reason here. (outcome 2, via adopting the fork)
- [x] Make sure exactly **one** place names the condition — met and collected, not re-deferred.
- [x] Confirm in game that the authenticated transport still answers (`smoke-test --probe-only` with the
      vendored hook installed).

### Validated in game — 2026-08-15

With the vendored hook installed and DCS at the main menu:

- the hook wrote a 40-hex password to `%USERPROFILE%\dcs-fiddle-token.txt`, and `smoke-test --probe-only`
  **authenticated and answered** (control table, `net.load_mission`, `exitProcess`, write dir all read);
- `--fiddle-token wrong-password-xxxx` was **rejected with 401** ("the DCS hook rejected the credentials").

So the local bypass is off, auth is enforced, and only the per-session password — which a browser cannot
read — is accepted. VMR-013 is closed, confirmed both ways rather than assumed.
