# SECREV-2 — act on the 2026-07-01 security review, finding by finding

Status: ✅ done — **all 140 findings decided**: 95 fixed, 9 already-fixed, 21 decided-deferred, 8 confirmed-open (the shared-password family David ruled on, tracked in `REVIEW-SECURITY-LAYER`), 5 does-not-reproduce, 2 wontfix. Every Critical / High / Medium / Security-flaw / Documentation / Error-bug tier is closed, **the server hook was deployed on 2026-08-11** so the two criticals are closed in production and not only in the repository, and ticket 07's cosmetic tail came due when `REFACTOR-MARKER-PARSER` shipped — it absorbed the 3 findings in its files, and the other 15 are deferred by that ticket's own written policy, listed by file so they resurface when someone edits one

Source: [`CODE_DOC_REVIEW_2026-07-01.md`](../../CODE_DOC_REVIEW_2026-07-01.md) — 2 606 lines, 140
findings, produced by 20 reviewers with an adversarial verifier that re-read each security/bug
finding and **refuted 6**, which were dropped. Severities below are post-verification.

> **Nothing in this review was ever tracked.** It has sat at the repository root for a month. The
> archived `SECREV` lot is a *different* thing — it closed an RCE in the Python `luadata` parser. This
> lot is the review's first appearance in the backlog.
>
> It was nearly deleted: while clearing the link gate's exemption list I proposed removing the file as
> a stale doc-review artefact, having judged it by its name without opening it. Recorded here because
> a near-miss on the only record of two critical findings is worth remembering.

## What the review found

| Severity | Count |
|---|---|
| 🔴 Critical | 2 |
| 🟠 High | 6 |
| 🟡 Medium | 24 |
| ⚪ Low | 95 |
| 🔵 Info | 13 |

By verdict: **34 CONFIRMED** (the verifier reproduced it), **10 PLAUSIBLE**, **96 UNVERIFIED**
(low-stakes, reviewer-asserted, never adversarially re-checked).

## Is it still current? Measured, not assumed

A month of lots landed after the review, so every finding was checked rather than taken on trust.
[`findings-triage.json`](findings-triage.json) holds all 140 machine-readable, each classified by
evidence that can be gathered mechanically:

- **untouched** (70) — the cited file has not changed since 2026-07-01, so the finding almost
  certainly stands.
- **review-needed** (70) — the file changed since; the triage lists the commits, so whoever executes
  reads the right diff rather than the whole file.
- **moot** — none. Every cited file still exists.

Regenerate with the script recorded in ticket 01; it takes seconds and re-dates itself.

### The eight high-severity findings, each verified by hand

| ID | Sev | Still current? | Evidence |
|---|---|---|---|
| **VMR-001** | 🔴 | **YES** | `REGISTER_PLAYER` interpolates `%s` into a Lua chunk run by `a_do_script`; no escaping anywhere in the hook. |
| **VMR-002** | 🔴 | **YES** | Same pattern on the pre-auth path — `string.format(REGISTER_PLAYER, playerName, …)` at three call sites. |
| **VMR-003** | 🟠 | **YES** | `veafGroundAI.lua` contains **no** reference to `veafSecurity`, `isAuthenticated` or any password constant. |
| **VMR-004** | 🟠 | **YES** | `veafRadio.lua` still builds a shell string with `string.format` and runs `l_os.execute(cmd)`. |
| **VMR-005** | 🟠 | **YES** | The `{k + 1: v …}` shift is still there with no index rewrite of the Lua text. |
| **VMR-006** | 🟠 | **YES** | `Metar(airport_icao)` is constructed and `.update()` is **never** called — in avwx the constructor does not fetch. |
| **VMR-007** | 🟠 | **YES** | Both languages still promise conversion profiles as future work, though `foothold` has shipped. |
| **VMR-008** | 🟠 | **NO — disproved** | See below. |

**VMR-008 is a false positive, and the repo already knew.** It says the English guides link to French
`.md` pages. `DOC-AUDIT-PASS` measured against the published HTML that `mkdocs-static-i18n` **rewrites
relative links**: an EN page linking `page.md` is served the EN version. 232 such "findings" were false
alarms in that audit, and `docs_check.py` carries the rule in its module docstring. The review's own
verdict for VMR-008 was UNVERIFIED, which fits. **Do not "fix" it** — doing so is what the audit
established as wrong.

Two more cross-references worth carrying:

- **VMR-026** (CONTRIBUTING links a non-existent `doc/developer/GUIDE.fr.md`) was **fixed on
  2026-08-05** by `TOOLING-REPO-LINK-GATE`, independently, before this triage existed. Close it, do not
  redo it.
- **VMR-013** (dcs-fiddle-server runs arbitrary Lua from unauthenticated HTTP) is **load-bearing for
  `FEAT-DCS-SMOKE-HARNESS`**, which was built on that hook the same week. Any hardening has to keep the
  harness working, or the harness has to move; decide that in ticket 04 rather than discovering it.

## The review's own thesis: fix the pattern, not the instance

Its §4 is the most valuable page, and this lot is organised around it rather than around 140 tickets.
One anti-pattern recurs at five layers — **untrusted text concatenated into code that then executes**:

| Layer | Finding |
|---|---|
| Server hook builds Lua from player names / commands | VMR-001, VMR-002 |
| `veafRadio` builds a shell command from marker text | VMR-004 |
| `lua_config_generator` interpolates `mission.yaml` strings into generated Lua | VMR-012 |
| `spawn_data_emitter` escapes only backslash and double-quote | VMR-010 |
| `dcs-fiddle-server` runs arbitrary Lua from unauthenticated HTTP | VMR-013 |

The review notes the project **already has the right tool** for the Python side — `_emit_lua_string` /
`_lua_long_string`, added by the FIX-ASSETS-NEWLINE lot — and simply does not apply it everywhere. Its
recommendation: one always-used "emit safe Lua literal" helper on the Python side, and
`string.format('%q', …)` for every value the server hook injects.

Three further themes it names: security gates that **fail open** because each handler opts in
(VMR-003, VMR-004); marker parameters that crash a handler when omitted or garbled (the VMR-019/025
family, a long tail); and integrity checks that **pass when their metadata is missing** (VMR-011, plus
the uncapped fetches of VMR-009 and the bridge/updater).

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | [Currency triage — method, tooling, and the eight verified](tickets/01-currency-triage.md) | ✅ |
| 02 | [Untrusted text into executed code — the five layers](tickets/02-unsafe-interpolation.md) | ✅ |
| 03 | [Security gates that fail open](tickets/03-fail-open-gates.md) | ✅ |
| 04 | [Integrity checks that pass when metadata is missing](tickets/04-fail-closed-integrity.md) | ✅ |
| 05 | [The two high-severity correctness bugs](tickets/05-correctness-bugs.md) | ✅ |
| 06 | [The 24 medium findings](tickets/06-medium-sweep.md) | ✅ |
| 07 | [The 108 low and info findings](tickets/07-low-info-sweep.md) | ✅ |

## What this lot will not do

- **Ship a fix nobody can test.** The server hook runs on VEAF servers and cannot be exercised here;
  `REFACTOR-SERVER-HOOK-CANONICAL` made the repo copy the deployable source, so a change has to be
  deployed to be real. Every hook ticket states how it was verified and what remains manual.
- **Treat UNVERIFIED as CONFIRMED.** 96 findings were never adversarially re-checked and the review says
  so. Ticket 07 samples before committing to a sweep; a finding that does not reproduce is closed as
  such, in writing.
- **Rewrite the review.** It stays as the source document. This lot records what happened to each
  finding; the file is not edited to reflect fixes, or it stops being a record of what was found on
  2026-07-01.

## Definition of Done

- Every one of the 140 has an outcome: fixed, already fixed elsewhere, disproved, or explicitly
  deferred with a reason. "Not looked at" is not an outcome.
- The two criticals are fixed and the fix is deployed, or the reason it is not is written down.
- The shared "safe Lua literal" helper exists and every interpolation site named in §4 routes through
  it — the review's point being that fixing five instances without the helper leaves a sixth to come.
- `ruff` / `mypy` / `pytest` green; `stylua` / `luacheck` green; CI's Lua suite green, since Lua tests
  cannot run on the machine that will likely write this.
