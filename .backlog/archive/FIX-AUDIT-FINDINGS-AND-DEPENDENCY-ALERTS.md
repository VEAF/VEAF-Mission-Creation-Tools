# FIX-AUDIT-FINDINGS-AND-DEPENDENCY-ALERTS — three nightly-audit findings and two Dependabot alerts

Status: ✅ done — 2026-09-28, [#1015](https://github.com/VEAF/VEAF-Mission-Creation-Tools/pull/1015) · archived 2026-10-02

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
| 01 | the Skynet monitor reports every lost contact | audit #89, plus the discarded `pcall` errors in the same two loops |
| 02 | NIOD is removed | audit #90 — dead code since the NIOD script was deleted |
| 03 | the logger forwards its varargs | audit #88, re-sized as hardening — includes the option of not doing it |
| 04 | the chatbot Worker's dependencies are watched | Dependabot #59, and the two directories Dependabot does not watch |
| 05 | veaf-logs refuses SHA-1 SSH signatures | Dependabot #62, mitigated since no fixed release exists |

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

## Tickets, in full

## 01 — the Skynet monitor reports every lost contact

Status: ✅ done — 2026-09-28

Source: `davidp57/security-audits#89`, checked against the code on 2026-09-28.

### The defect

`VeafSkynetMonitorTaskContacts:Execute` (`src/scripts/veaf/veafSkynetIadsMonitor.lua:482-488`)
walks `self.TrackedUnits` with `pairs` and removes from that same table inside the loop.
`TrackedUnits` is a sequence (`AddTrackedContact` uses `table.insert`), and `RemoveTrackedContact`
goes through the local `tableRemove`, which calls `table.remove(tab, i)` and shifts every later
element down one slot. The iterator resumes after the index it already returned, so each element
shifted onto a visited slot is skipped.

With `{A, B, C}` all lost in the same beat: A is removed, C is visited at index 2, the loop ends.
**B is never reported lost and stays in `TrackedUnits`**, so when it reappears the detection loop
(474-479) sees it as already tracked and reports nothing either. The contact is dead both ways for
the rest of the mission. Two aircraft of one flight leaving IADS cover together are enough.

### Also in the same two loops

`local err, errmsg = pcall(self.OnDetectedAction, …)` (478) and its twin (486) capture both values
and read neither. `err` is in fact the success flag, and a mission maker's action that raises is
swallowed without a log line. Log the failure at `error` with the message `pcall` returned.

### What to do

* Walk the sequence backwards (`for i = #self.TrackedUnits, 1, -1`), or iterate a copy. Backwards
  is the smaller change and keeps the removal where it is.
* Log a failed `OnDetectedAction` / `OnLostAction` with the contact name and the error message.

### Test

`test/lua/test_veafSkynetIadsMonitor.lua` never exercises `VeafSkynetMonitorTaskContacts:Execute`.
Add, with a stub IADS whose `getContacts()` the test controls:

* three tracked contacts, all gone in one call → `OnLostAction` called three times,
  `TrackedUnits` empty. **Fails before the fix** (two calls, one leftover).
* a lost contact that comes back → `OnDetectedAction` called again.
* an `OnLostAction` that raises → the loop still finishes and an error line is logged.

## 02 — NIOD is removed

Status: ✅ done — 2026-09-28

Source: `davidp57/security-audits#90`, checked against the code and the production logs on
2026-09-28. Decided by David the same day: *"oui, retire NIOD"*.

### What the finding said

`veafRemote.addNiodCallback` (`src/scripts/veaf/veafRemote.lua:55-114`) loses its error message on
both failure paths: `veaf.p(status)` where `retval` holds the `pcall` message (108), and a format
with one `%s` for two values, so the list of bad parameters never reaches the log (96-99). Both
defects are in the code as described.

### Why that code is removed rather than fixed

It cannot run.

* **NIOD itself is gone.** It was a community script, `src/scripts/community/NIOD.lua`, added with
  v2.6.0 (2020-06-23): a LuaSocket TCP server on `127.0.0.1:15487` inside the mission, speaking
  JSON, built on MOOSE, and driven from Node by the `niod-core` npm package, which called the Lua
  functions stored in `niod.functions`. The script was deleted on 2025-09-25 (`74df68a3`, first
  version of the scripts injector). Nothing in the repository defines the `niod` global any more.
* **Nothing registers a callback anyway.** `veafRemote.buildDefaultList()` declares `test` and
  `login` under `local TEST = false` (128-155). The audit read past that guard when it wrote that
  `login` is registered.
* **Production agrees.** The six `dcs.log` of `dcs.veaf.org` carry neither
  `Adding NIOD function` nor `NIOD is not loaded` — the two lines this code logs on either branch.

Fixing two lines nothing calls, and testing them, maintains dead code the next audit will read
again. The dead `login` path also logs the password in clear (147, `TODO remove password from log`).

### What to remove

In `src/scripts/veaf/veafRemote.lua`:

* the *NIOD callbacks* section and `veafRemote.addNiodCallback`;
* the comment block about `addNiodCommand` (116-121), which only makes sense next to it;
* `veafRemote.buildDefaultList()` and its *default endpoints list* banner, since its whole body is
  the dead `if TEST` block, and the call to it in `veafRemote.initialize()`.

What stays untouched: everything else in the module — the bridge with `VEAF-Server-hook.lua`.
`registerUser` / `registerUserSlot` / `getRemoteUser*` track who is connected, with what rights and
in which aircraft (read by `veafSecurity` and `veafEventHandler`), and `registerRemoteModule` /
`executeCommandFromRemote` hand a chat command to the module that owns it (carrier, air, point,
secu, alias, atis, missile guardian). It is live: the hook is installed on all six production
servers, and `public1`'s `dcs.log` shows `REMOTE|I|executeCommandFromRemote` lines on 2026-09-25
and 26. There is no SLMOD side left to keep either — the bridge went in August 2021 and its
remains with `SECREV-2` / VMR-130; the comments explaining that absence stay.

Also:

* `test/lua/test_veafRemote.lua` — `TestVeafRemoteBuildDefaultList` goes; the test around line 390
  that stubs `buildDefaultList` no longer needs to; add `addNiodCallback` and `buildDefaultList` to
  the assertions that pin removed entry points (next to `test_addNiodCommand_is_gone_too`).
* `doc/mission-maker/scripts/README.md` / `.en.md`, line 93: the `veafRemote.lua` row says
  *NIOD / SLMOD remote command integration*, and both halves are wrong. It becomes what the module
  does: *bridge with the VEAF server hook — player rights and chat commands* (FR: *pont avec le
  hook serveur VEAF : droits des joueurs et commandes du chat*).
* `CHANGELOG.md`: one entry — NIOD support removed, it had not worked since the script left the
  repository.

### Check

`git grep -niE 'niod'` over `src/`, `test/lua/` and `doc/` returns nothing but the new absence
assertions; `poetry run test-lua` and the Lua gate pass; `docs-check` passes.

## 03 — the logger forwards its varargs

Status: ✅ done — 2026-09-28

Source: `davidp57/security-audits#88`, **re-sized** after measurement on 2026-09-28.

### What the finding said, and what was measured

The five `veaf.Logger` methods (`src/scripts/veaf/veaf.lua:4399-4435`) call
`veaf.Logger.formatText(text, arg)`: they read the implicit `arg` table of a Lua 5.0 vararg
function instead of forwarding `...`, and `formatText` then reads its first vararg as that table.
The finding claimed DCS runs LuaJIT, where `arg` does not exist, so that 727 call sites log raw
`%s` with none of their values.

**That consequence does not happen.** The six production `dcs.log` files on `dcs.veaf.org` all
carry `VEAF|I|…: veaf.Development=[false]` — the formatted output of
`info("veaf.Development=%s", …)` at `veaf.lua:5502` — and none of their 4 000+ VEAF lines holds a
raw placeholder. The mission scripting environment has `arg` (PUC-Rio 5.1 with
`LUA_COMPAT_VARARG`, as the CI runs it). See the PRD for the lines.

What stays true: the logger that every module uses depends on a compatibility feature, and the
other copy of the same logger, `dcsDataExport.lua:91-95`, was already moved off it (SECREV-2 /
VMR-079), with a comment explaining why. The two copies disagree.

### The options

**a) Align `veaf.lua` on `dcsDataExport.lua`** — the methods forward `...`, `formatText` counts
them with `select("#", ...)` and keeps its `"[nil]"` padding. About fifteen lines, no behaviour
change today, and it removes the only reason the logger would break if the scripting environment
ever dropped the compatibility flag. Cost: it touches the function behind every log line of the
framework, so the method-level test below is not optional.

**b) Do not do it.** Today's behaviour is correct and measured in production; the change buys
insurance against a runtime switch nobody has announced. Record the measurement in
`known-limitations.yaml` (`kind: dcs`: *the mission environment exposes `arg` in vararg
functions*) so the next audit does not re-file it.

**Recommendation: a)**, low priority within the lot. The two copies of one logger disagreeing is
the kind of thing that re-grows findings, and the test it brings is the one nobody has: every
existing test of `formatText` calls it directly or with strings free of `%`.

### Test (option a)

At the **method** level, not `formatText`: `log:info("a=%s b=%s", 1, nil)` produces `a=1 b=[nil]`,
for each of the five levels. This cannot fail before the fix under the CI's PUC-Rio 5.1 — the
premise that would make it fail is the one the measurement refuted — so say so in the test's
comment rather than claiming a regression test.

## 04 — the chatbot Worker's dependencies are watched

Status: ✅ done — 2026-09-28

Source: Dependabot alert #59 (high), open on 2026-09-28.

### The alert

`poc/doc-chatbot/worker/package-lock.json` locks `sharp` 0.35.2, affected by two libheif advisories
(GHSA-g89c-p67h-r497, GHSA-2jg2-4ch7-h545), fixed in 0.35.4. It is a **dev** dependency, pulled by
`wrangler` → `miniflare` for the local `wrangler dev` server. The deployed Worker never contains
it, so exposure is limited to a maintainer's machine running `wrangler dev` on a hostile image —
which that server never processes. Real, low practical risk, and cheap.

### Why no PR ever came

`.github/dependabot.yml` watches two ecosystems, both at `/`: `pip` and `github-actions`. So:

* `poc/doc-chatbot/worker` (npm) is **not watched** — the alert exists, the PR never will;
* `services/support-bot` (its own `pyproject.toml` and `poetry.lock`) is **not watched** either,
  although it is deployed and holds the Discord token.

### What to do

* Bring `sharp` to ≥ 0.35.4 in the Worker's lock (`npm update sharp`, or bump `wrangler` if
  `miniflare`'s range does not allow it). Check `wrangler deploy --dry-run` still builds.
* Add two `updates` entries to `dependabot.yml`: `npm` at `/poc/doc-chatbot/worker` and `pip` at
  `/services/support-bot`, with the same grouping and target branch as the existing `pip` entry.
  `target-branch` must **not** be set: `develop` is the default branch, and naming a target branch
  turns security updates off for that entry.

### Check

The alert closes by itself once the lock on `develop` carries 0.35.4 — verify with
`gh api repos/VEAF/VEAF-Mission-Creation-Tools/dependabot/alerts/59 --jq .state` after the merge.

## 05 — veaf-logs refuses SHA-1 SSH signatures

Status: ✅ done — 2026-09-28

Source: Dependabot alert #62 (low), CVE-2026-44405 / GHSA-r374-rxx8-8654, open on 2026-09-28.

### The alert

`paramiko` up to 4.0.0 accepts the SHA-1 `ssh-rsa` signature algorithm in `rsakey.py`. **No release
fixes it**, so Dependabot can raise no PR, and bumping is not an answer. `paramiko` is an optional
dependency (extra `logs`), used in one place: `veaf_logs/remote.py:_connect`, the SSH/SFTP tail of a
remote `dcs.log`.

### What to do

Refuse SHA-1 at the call site, which paramiko supports: pass
`disabled_algorithms={"pubkeys": ["ssh-rsa"], "keys": ["ssh-rsa"]}` to `client.connect`. RSA keys
keep working through `rsa-sha2-256` / `rsa-sha2-512`; Ed25519 — what `dcs.veaf.org` uses — is
untouched.

### Test

`test/python/veaf_logs/test_remote.py` already drives `_connect` against a fake
`paramiko.SSHClient` (the class around line 398); assert there that
`connect` receives `disabled_algorithms` with `ssh-rsa` in both lists. Then check once by hand
against `dcs.veaf.org` that the remote tail still connects.

### After the merge — David's call

Dismiss alert #62 on GitHub as *"mitigated: SHA-1 disabled at the only call site"*. It stays open
otherwise until paramiko ships a fix, and an alert that stays red for a known reason teaches
everyone to stop reading them.

### Quality ratchet

If `veaf_logs/remote.py` is still under a mypy `ignore_errors` override, this is a mechanical
one-argument edit and does not trigger the obligation to drop it (`CLAUDE.md` §3).
