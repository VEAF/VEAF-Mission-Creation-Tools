# Lot FIX-SERVERHOOK-UNKNOWN-PILOT-PARSE — shared pilots list not loaded + crash on unlisted pilot

Status: 🔄 in-progress
Branch: fix/serverhook-unknown-pilot-parse → PR → develop-v6

## Problem Statement

Reported by David from a live session on the VEAF "privé 2" dedicated server, and
confirmed against the server `dcs.log`. This surfaced only after
[FIX-SERVERHOOK-CHAT-SIM-LOGGER](../archive) (#590) revived the dead chat callback
(`onChatMessage` → `onPlayerTrySendChat`): the whole command-parsing path became
reachable for the first time in weeks.

### 1. The shared pilots list is never loaded (root cause)

The VEAF servers all live side by side under `C:\Users\veaf\Saved Games\`
(`private1_server`, `private2_server`, …) and are meant to share **one**
`veaf-pilots.txt` placed in that `Saved Games\` root. But `loadPilots` builds the
path from `VEAF_SERVER_DIR = writedir()\scripts\hooks\` — i.e. the *per-server*
Hooks folder, where the file does not exist. The server log shows, on every
`loading pilots`:

```
ERROR LuaHooks: [...VEAF-Server-hook.lua]:557: no file
  'C:\Users\veaf\Saved Games\private2_server\scripts\hooks\veaf-pilots.txt'
```

Consequence: the pilots table stays empty, so **every** connecting pilot (admin
included) is "Unknown" — `VEAF pilot [...]` appears **zero** times in the log,
`Unknown pilot ... connecting` 8 times. No permission works.

The repo hook has always looked under `scripts\hooks\`; the hand-edited variant that
ran on the servers before #604 (REFACTOR-SERVER-HOOK-CANONICAL) evidently resolved a
relative path one level up. Making the repo hook the single deployable source
re-exposed the mismatch.

### 2. `loadPilots` crashes instead of reporting a missing file

`local file = assert(loadfile(filepath))` **throws** when the file is absent, so the
`if not file then logError ... return end` branch right below is dead code and the
failure is a raw Lua exception rather than a VEAF-readable error.

### 3. `parse` indexes a `nil` pilot

For an unlisted pilot, `parse` logs the "Unknown pilot" warning but keeps going and
then reads `pilot.level`, throwing `attempt to index local 'pilot' (a nil value)`
(`VEAF-Server-hook.lua:413`) — observed 3× when Reaper sent `/secu login`.
(`/secu` is a DCSServerBot command, not a VEAF one; the VEAF hook only logs the
unknown pilot and denies it.)

## Solution

- **Fix 1**: default the pilots-file directory to the shared `Saved Games\` root
  (`VEAF_SHARED_DIR = writedir()\..\`), one level above the server folder. One file
  serves every server with no per-server config; `pilotsDir` still overrides it for a
  standalone server. `VEAF_SERVER_DIR` is kept (public global, may be used by a
  companion hook).
- **Fix 2**: load defensively — replace `assert(loadfile(...))` with a checked
  `loadfile` that logs a clear error (`no pilot will be recognized and every command
  will be denied`) and returns without crashing.
- **Fix 3**: an unlisted pilot gets `level = -1` (no power at all), the same
  convention `onPlayerConnect` already uses, so the command is cleanly denied.
- Bump the hook version (`2.7.1`); update the install docs (FR/EN) to state the
  pilots file lives in the shared `Saved Games\` root by default.

## Out of scope / notes

- No unit test: this hook runs in the DCS GameGUI environment (`net`/`Sim`/`lfs`
  globals) and has no test harness. Behaviour verified by reading the production log.
- No `pyproject`/`plugin.json` bump: Lua-only hook fix (same convention as #590).
- **Deployment is manual** (no pipeline): after merge, re-push the hook to the
  servers. The `veaf-pilots.txt` already sits at `C:\Users\veaf\Saved Games\` — with
  the new default it will be picked up without touching each server.

## Tickets

1. `01-shared-pilots-path.md` — default the pilots file to the shared Saved Games root.
2. `02-defensive-loadpilots.md` — stop crashing on a missing/invalid pilots file.
3. `03-parse-nil-pilot.md` — deny an unlisted pilot instead of crashing.
