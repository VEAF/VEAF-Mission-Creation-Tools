# FIX-FIDDLE-HOOK-CLOBBERS-VEAF — the debug hook decapitates the framework mid-mission

Status: ✅ done — 2026-08-16, **confirmed in game**: with the renamed hook deployed, the CTLD menu appears

Origin: testing `FIX-CTLD-NEVER-INITIALIZED` in game on 2026-08-16. CTLD started correctly and the
FOB spawned without the crash — and there was still **no CTLD entry in the F10 menu**. The cause is
a different defect, in a file this repo shipped the day before.

## The measurement

`src/scripts/other/dcs-fiddle-server.lua` opened with `veaf = {}` (line 14), inside the block this
repo added (`-- START OF VEAF CHANGES`, `FIX-SECREV2-EXPIRED-DEFERRALS` ticket 02, 2026-08-15). The
hook is injected into the **mission scripting environment** — the same Lua state the VEAF framework
lives in — and it is injected **after** the mission scripts have loaded. From the DCS log:

```
15:39:39.318  STATIC VEAF scripts loading
15:39:39.431  VEAF|I|log: CTLD initialized.
15:39:39.460  VEAF-SPAWN|I|spawnFob: Spawned FOB FOB YD6647 #10228     <- the CTLD fix works
15:39:55.167  MissionScripting::initialize [dcs-fiddle-server] - Starting fiddle server in the
              mission scripting environment...
15:39:55.200  ERROR  veaf-scripts.lua:21124: attempt to index field 'loggers' (a nil value)
              in function 'checkEventKnown' <- in function 'onEvent'
```

**33 milliseconds** between the hook starting and the framework table being gone. From that point on:

- `veaf.loggers` is nil, so `veafEventHandler.checkEventKnown` raises on **every** DCS event — 14
  occurrences in one 100-second session;
- `veaf.ctldLogLevels` is nil, so the `ctld.utils.log` override VEAF installs raises, and it raises
  **inside CTLD's own `onEvent`** (`CTLD.lua:24578`). That is the handler carrying
  `onPlayerEnterUnit`, the function that builds a player's CTLD radio menu. It dies before it gets
  there.

So the reported symptom — "no CTLD menu in the UH-1H" — is this, not CTLD.

## Why it took a wrong suspect first

The symptom is identical to the one `FIX-CTLD-NEVER-INITIALIZED` fixes, and it appeared on the very
mission built to verify that fix. What separates them is that the CTLD lot's evidence was all in the
first 200 ms of the log, and this one only starts 16 seconds in — after a line about a *debug hook*
that has nothing to do with either. Tripack's log carries no such error, because he has no hook
installed: the two defects could not have been told apart from his report alone.

## The fix

The hook's table is renamed `veafFiddle`. Nothing outside the hook referenced `veaf.sanitizedModule`
— checked across Lua, Python and the docs — so the rename has no other caller to follow.

A grep-based guard in `test_dcs_fiddle_token.py` fails on a global `veaf` assignment, or on a
`function veaf.…` definition, in that file. Crude, but the failure it prevents is invisible until
someone flies a mission, and the file is vendored from upstream and re-synced.

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | Rename the hook's global table | ✅ |

## What is left

The installed hook is a **hand-deployed copy** at
`%USERPROFILE%\Saved Games\DCS\Scripts\Hooks\dcs-fiddle-server.lua` — no pipeline copies it — so the
fix reaches a workstation only when someone copies it over. David's confirmation run needs that copy
first; the command is in the ticket.

## What the ticket changed

**01 — Rename the hook's global table.** `src/scripts/other/dcs-fiddle-server.lua`,
`test/python/veaf_libs/test_dcs_fiddle_token.py`.

`veaf = {}` becomes `veafFiddle = {}`, and its five functions follow: `sanitizedModule`,
`tokenFilePath`, `generateToken`, `writeToken`, `readToken`. A comment at the declaration says why the
name matters, because whoever next re-syncs this file from upstream will re-apply the VEAF patch.
`sanitizedModule` was grepped across `*.lua`, `*.py` and `*.md` and appears only in the hook itself,
its own prose and the changelog. `FIDDLE.USERNAME = 'veaf'` is a string and stays.
