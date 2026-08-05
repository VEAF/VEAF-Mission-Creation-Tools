# Lot FIX-SERVERHOOK-UNKNOWN-PILOT-PARSE — shared pilots list not loaded + crash on unlisted pilot

Status: ✅ done
Branch: fix/serverhook-unknown-pilot-parse → PR #620 → develop (merged)

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

---

## 01 — Default the pilots file to the shared Saved Games root

Status: ✅ done

### Context

`loadPilots` looked for `veaf-pilots.txt` under `VEAF_SERVER_DIR`
(`writedir()\scripts\hooks\`), the per-server Hooks folder. The VEAF servers share a
single `veaf-pilots.txt` in the parent `Saved Games\` root, so the file was never
found and no pilot was ever recognized.

### Change

- Add `VEAF_SHARED_DIR = DCS_DIR .. [[..\]]` (parent of `writedir()`, i.e. the shared
  `Saved Games\` root).
- Default the load path to `(veafServerHook.pilotsDir or VEAF_SHARED_DIR)`.
- Keep `VEAF_SERVER_DIR` (public global, may be referenced by a companion hook).
- Update the `pilotsDir` comment and the FR/EN install docs.

### Done when

- A shared `Saved Games\veaf-pilots.txt` is loaded by every server with no
  per-server config; `pilotsDir` still overrides for a standalone server.

---

## 02 — Stop crashing on a missing/invalid pilots file

Status: ✅ done

### Context

`local file = assert(loadfile(filepath))` throws when the file is absent, so the
`if not file then logError ... return end` branch right below is unreachable dead
code and the failure surfaces as a raw Lua exception
(`LuaHooks ...:557: no file '...'`).

### Change

Replace `assert(loadfile(...))` with a checked `loadfile` capturing the error:

```lua
local file, err = loadfile(filepath)
if not file then
    veafServerHook.logError(string.format("Cannot load pilots list file [%s]: %s -- no pilot will be recognized and every command will be denied", veafServerHook.p(filepath), veafServerHook.p(err)))
    return
end
```

### Done when

- A missing or invalid pilots file logs a clear VEAF error and leaves the hook
  running (pilots table stays as-is), instead of raising a Lua exception.

---

## 03 — Deny an unlisted pilot instead of crashing

Status: ✅ done

### Context

`veafServerHook.parse` logs the "Unknown pilot" warning for a pilot absent from the
list but keeps going and then reads `pilot.level`, throwing
`attempt to index local 'pilot' (a nil value)` (`VEAF-Server-hook.lua:413`). Observed
3× when an unlisted pilot sent `/secu login`.

### Change

In the `if not pilot then` guard, assign the no-power sentinel already used by
`onPlayerConnect`:

```lua
pilot = { level = -1 } -- unknown pilot: no power at all (same convention as onPlayerConnect)
```

Every command threshold is `>= 0` or higher, so `level = -1` is denied everywhere and
`parse` returns `false` without touching a `nil` value.

### Done when

- An unlisted pilot sending any `/command` is cleanly denied; no Lua error is raised.
