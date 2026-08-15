# 02 — The fiddle-server port: re-anchor the deferral or close it

Status: 🧑 waiting-human
Type: chore
Finding: VMR-013 (Security flaw, **MEDIUM**), `src/scripts/other/dcs-fiddle-server.lua:270`

## The finding, and why its own severity understates it

`dcs-fiddle-server` **executes arbitrary Lua from unauthenticated HTTP requests**. No token, no origin
check. [ADR 0019](../../../docs/adr/0019-dcs-fiddle-server-stays-unauthenticated-for-now.md) accepted
that, for now, with reasons.

The triage entry adds something the review did not say, and it is the part to carry forward:

> *Severity is understated in the review: `cors='*'` plus a GET channel means **any web page visited
> while the hook is installed gets code execution**, so "loopback only" is not the protection it sounds
> like.*

That is the sentence to re-read before deciding this can wait again.

### The unauthenticated half is no longer a claim — 2026-08-15

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

## Why it was deferred, and what has changed

Deferred because *"no DCS is available to test a change to the transport `FEAT-DCS-SMOKE-HARNESS` speaks
through, and shipping untested auth there breaks the harness invisibly."* Two things did ship instead: a
danger warning in the harness documentation, at the point where it tells you to install the hook, and
**the token design, written down in ADR 0019 to be implemented with the harness's remaining slice, where
it can be tested.**

What changed by 2026-08-11: the harness **has** run in a live DCS. What did *not* change: its ticket 04
(*"Assert VEAF through the mission bridge, not the hook"*) explicitly **keeps the hook** for driving DCS —
locate, launch, load, quit — and only moves the `veaf-*` assertions to the mission bridge. So the
dependency is real and still live.

## This ticket's first job is to decide whether it should exist

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

## Decision — outcome 2, and the vendored file was the wrong one (2026-08-15)

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

## Tasks

- [x] Read ADR 0019's token design and check it against what the harness actually needs.
- [x] Pick an outcome and write the reason here. (outcome 2, via adopting the fork)
- [x] Make sure exactly **one** place names the condition — met and collected, not re-deferred.
- [ ] Confirm in game that the authenticated transport still answers (`smoke-test --probe-only` with the
      vendored hook installed).

## Blocked on

David: reinstall the vendored hook and run one `--probe-only` to confirm the auth does not break the transport.
