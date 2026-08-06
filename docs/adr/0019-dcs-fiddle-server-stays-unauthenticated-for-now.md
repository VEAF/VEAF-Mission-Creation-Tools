---
status: accepted
---

# DCS Fiddle keeps its open port until the smoke harness can prove a token works, and the docs say so today

`src/scripts/other/dcs-fiddle-server.lua` is a third-party developer tool, already carrying VEAF
changes, that a developer copies by hand into `Saved Games/.../Scripts/Hooks/`. It listens on
`127.0.0.1:12080` (mission environment) and `127.0.0.1:12081` (hook environment), base64-decodes the
Lua it finds in the request path, and runs it. There is no token, no origin check, and no
authentication of any kind.

[`FEAT-DCS-SMOKE-HARNESS`](../../.backlog/FEAT-DCS-SMOKE-HARNESS/PRD.md) was built on that hook the
same week the security review naming it was filed. Hardening the transport and keeping the harness
alive is therefore **one decision**, not two — which is the whole reason this ADR exists rather than
a commit.

## What the exposure actually is

The review (SECREV-2, finding VMR-013) rates it MEDIUM and reasons partly from "any local process".
That reasoning understates it, and the understatement is the interesting part:

- The command channel is a **GET**, with the Lua in the URL path.
- The server answers with **`Access-Control-Allow-Origin: *`** (`server_config = { cors = "*" }`).

A cross-origin `GET` is *sent* by a browser without a preflight. So any web page a developer visits
while DCS is running with this hook installed can execute Lua in the mission and hook environments
of that developer's machine — the request runs whether or not the response is readable, and the
wildcard makes it readable too. "It only binds to loopback" is not the protection it sounds like:
the browser is already on loopback. Private-network-access protections exist in some browsers and
cannot be relied on.

So the honest severity on a developer workstation is higher than MEDIUM, and the review's own
closing line is the important one: **this must never be present on a live server.**

## Decision

Three parts, deliberately split by what can be *verified* today.

### 1. The port stays open for now — stated, not overlooked

No token, no CORS change in this lot. Not because the risk is acceptable in the abstract, but
because **no DCS is available to test a change to it**, and this hook is the transport the smoke
harness speaks through. Shipping untested authentication to the one channel that reaches a running
DCS would break the harness in a way nobody could observe until someone had a DCS in front of them —
the same trap `FEAT-DCS-SMOKE-HARNESS` avoided when it cut launching and quitting DCS rather than
writing them blind.

### 2. The mitigation that costs nothing ships today: say so, loudly, where it is installed

The harness documentation tells a developer to copy this file into `Scripts/Hooks`. Until this ADR
it did that with no warning at all. It now states what installing the hook grants and that it must
be removed afterwards and never deployed to a server. A warning in the page that causes the
installation is worth more than a warning in a file nobody opens, and unlike a code change it can be
verified by reading it.

### 3. The token is designed here and implemented with the harness, where it can be tested

When the harness's remaining slice is built on a machine with DCS, it carries the authentication
with it:

- The hook writes a **per-session secret** to a file beside itself at startup, and requires it on
  every request.
- The harness client reads that file. This is why a token works here where it would not for a
  browser: the client shares a filesystem with the hook and a web page does not, so the secret
  never has to be configured by a human or committed anywhere.
- `Access-Control-Allow-Origin` loses its wildcard. Our client is not a browser and does not care.
  The upstream DCS Fiddle web UI does — whoever implements this must decide whether VEAF still wants
  that UI, and say so, rather than discovering it is broken.

Doing this **with** the harness rather than before it is the point: the harness is what proves the
authenticated transport still works, and it cannot prove anything from a machine with no DCS.

## Consequences

- A developer running the hook is running an open remote-code-execution port for as long as it is
  installed. That is now written where they install it, so it is a choice rather than a surprise.
- The harness keeps working unchanged, and the eventual token lands with the tests that can
  demonstrate it.
- If the hook is ever found on a VEAF server, that is an incident, not a configuration mistake —
  it de-sanitizes nothing by itself but grants arbitrary Lua in both environments to anything that
  can reach the port.
- This ADR is the record that the open port was **decided** and not merely left. If a later reviewer
  finds VMR-013 still open, this is the answer to "did anyone look at it?".

## Alternatives rejected

**Add the token now, untested.** Rejected: the failure mode is a harness that silently cannot reach
DCS, discovered by the next person who has one — and they would reasonably suspect their own setup
first.

**Move the harness off this hook.** Rejected for now. The measured fact the harness rests on is that
`onSimulationFrame` fires at ~28 Hz *with no mission loaded*, verified with this hook answering at
the main menu. The in-mission `dcs-serve` bridge cannot answer before a mission exists, which is
exactly when the harness needs to load one.

**Drop DCS Fiddle entirely and write our own.** Rejected as premature: the hook already works, and
replacing it would mean re-deriving the request handling before the harness has answered a single
one of the four questions it exists to answer.
