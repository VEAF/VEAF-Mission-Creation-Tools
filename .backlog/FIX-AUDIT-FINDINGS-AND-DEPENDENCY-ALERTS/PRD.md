# FIX-AUDIT-FINDINGS-AND-DEPENDENCY-ALERTS — three nightly-audit findings and two Dependabot alerts

Status: 🔄 in-progress — all five tickets done 2026-09-28, PR open

Origin: David, 2026-09-28 — *"on va prendre en compte les PR dependabot et les tickets d'analyse de
code et sécu"*. Two sources, gathered into one lot:

* the nightly audit routine's findings against this repository, filed as
  `davidp57/security-audits#88`, `#89` and `#90` (all three labelled *qualite*, none *securite*);
* the two open Dependabot alerts, `#59` (high) and `#62` (low). No Dependabot **pull request** is
  open: the last ones (#976, #964, #948) merged on 2026-09-21, and neither alert has a PR because
  one sits in a directory Dependabot does not watch and the other has no patched release.

Every finding was checked against the code on 2026-09-28 before being written here, as the audit
repository's own procedure asks — an unsupervised agent wrote them.

## What the check found

| Source | Claim | Verdict | Ticket |
|---|---|---|---|
| audit #89 | the Skynet monitor forgets one of two contacts lost in the same beat | **real** — `pairs` over `TrackedUnits` while `table.remove` shifts it (`veafSkynetIadsMonitor.lua:482-488`) | 01 |
| audit #90 | a failing NIOD callback never says why | defects **real, code unreachable** — NIOD left the repository on 2025-09-25, and the only callbacks sit under `local TEST = false`. NIOD is removed instead (David, 2026-09-28) | 02 |
| audit #88 | the `veaf.lua` logger loses every value under LuaJIT: 727 log lines reach `dcs.log` with raw `%s` | **premise refuted** — see below. The code does lean on `LUA_COMPAT_VARARG`; the consequence does not happen | 03 |
| Dependabot #59 (high) | `sharp` 0.35.2, libheif vulnerabilities, fixed in 0.35.4 | real, **dev-only**: pulled by `wrangler` → `miniflare` in `poc/doc-chatbot/worker`, used by `wrangler dev`, never in the deployed Worker | 04 |
| Dependabot #62 (low) | `paramiko` ≤ 4.0.0 accepts SHA-1 (`ssh-rsa`) signatures, no fixed release | real, optional extra `logs` only (`veaf_logs/remote.py`, the remote `dcs.log` tail) | 05 |

### Why #88's premise does not hold

The finding rests on *"DCS World runs on LuaJIT"*, where the implicit `arg` table of a vararg
function does not exist. Measured on the production servers on 2026-09-28 (read-only, over SSH, the
six `dcs.log` of `dcs.veaf.org`): `veaf.lua:5502` logs `info("veaf.Development=%s", …)` at every
load, and every instance writes it **formatted** —

```
2026-09-27 20:54:48.075 INFO    SCRIPTING (Main): VEAF|I|4422: veaf.Development=[false]
2026-09-26 17:18:25.084 INFO    SCRIPTING (Main): VEAF|I|silenceAtcOnAllAirbases|1169: silencing ATC at base Wittstock
```

and across more than 4 000 VEAF lines in those six logs, **not one** carries a raw `%s` or `%d`.
The mission scripting environment has `arg`, so the 727 call sites log their values. What remains
true is narrower: the five methods depend on a Lua 5.0 compatibility feature, while
`dcsDataExport.lua:91-95` already carries the version that does not. That is ticket 03, sized as
hardening rather than as a live defect.

## Tickets

| # | Ticket | What it is |
|---|--------|------------|
| 01 | [the Skynet monitor reports every lost contact](tickets/01-skynet-monitor-reports-every-lost-contact.md) | audit #89, plus the discarded `pcall` errors in the same two loops |
| 02 | [NIOD is removed](tickets/02-niod-is-removed.md) | audit #90 — dead code since the NIOD script was deleted |
| 03 | [the logger forwards its varargs](tickets/03-logger-forwards-its-varargs.md) | audit #88, re-sized as hardening — includes the option of not doing it |
| 04 | [the chatbot Worker's dependencies are watched](tickets/04-chatbot-worker-dependencies-are-watched.md) | Dependabot #59, and the two directories Dependabot does not watch |
| 05 | [veaf-logs refuses SHA-1 SSH signatures](tickets/05-veaf-logs-refuses-sha1-ssh-signatures.md) | Dependabot #62, mitigated since no fixed release exists |

## Definition of done

* Ticket 01 ships with the test the audit said was missing, and that test fails before the fix.
  Ticket 02 ships with tests pinning the absence of the removed entry points.
* The Lua and Python quality gates pass (§6 of `CLAUDE.md`); `CHANGELOG.md` has one entry per
  user-visible fix under `[Unreleased]`.
* One branch, one PR. Commit messages reference the findings as `davidp57/security-audits#<n>` —
  a bare `#<n>` would point at this repository's issues.
* **Left to David, after the merge**: closing the three audit issues (#88 with the production
  measurement above rather than a fix claim, #90 as *code removed*), and dismissing Dependabot #62 as mitigated. The
  audit repository's `state/` is not touched: its routine marks a finding resolved on its next run.

## Scope

Nothing here touches what a mission maker configures: no `mission.yaml` key, no default changes.
The one documentation change is the scripts page's `veafRemote.lua` row, which stops advertising
NIOD. The audit's findings on other repositories (CTLD,
VEAF-Servers, …) are not part of this lot.
