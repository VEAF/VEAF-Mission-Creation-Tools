# FIX-BUNDLE-LOCAL-LIMIT — the VEAF bundle no longer loads in DCS: more than 200 top-level locals

Status: 🧑 waiting-human — merged on `develop` (#1102); waits for Kolkhida mission 1 loading in DCS

## Problem

David, 2026-10-08, testing *Kolkhida* mission 1 rebuilt from `develop`: "j'ai des erreurs dans la mission 1 (log DCS)".

```text
SCRIPTING (Main): Mission script error: [string "l10n/DEFAULT/veaf-scripts.lua"]:81100: main function has more than 200 local variables
SCRIPTING (Main): Mission script error: [string "l10n/DEFAULT/veaf-config.lua"]:8: attempt to index global 'veaf' (a nil value)
```

The build concatenates every VEAF module into one `veaf-scripts.lua`, so every module's top-level `local` lives in one scope — the bundle's main chunk.
Lua 5.1 refuses a function with more than 200 active locals (`LUAI_MAXVARS`), and DCS rejects the whole file: no VEAF module loads, and everything after it fails (`veaf-config.lua`, `veaf-spawn-data.lua`, CSAR's "The VEAF framework has not been loaded!").

Measured with Lua 5.1.5, 2026-10-08:

| Bundle | `loadfile` | top-level `local` lines |
|---|---|---|
| built 2026-10-07 (before the campaign, opposition and convoy lots) | OK | 190 |
| built from `develop` at `af95c619` | **the error above, line 81100** | 198 (202 names) |

Released 6.28.0 is below the limit; every mission built from `develop` since the assault convoys (#1100) does not run.

No test executed the bundle: every Lua test loads the source modules one by one, each in its own chunk, where the limit is never approached.

## What the lot does

- The build wraps each module in a `do … end` block: a module's locals die at its `end`, so the limit applies per module (the largest, `veafSecurity`, has 33), and a module no longer sees another module's locals — the scoping it has when the tests load it alone.
- A test builds the bundle exactly as the build does, then loads and runs it under Lua 5.1 with the DCS mocks; the CI Lua job runs it with a Lua 5.1 interpreter, where it may not skip.
- The trap goes into `known-limitations.yaml` (`kind: dcs`) and `docs/agents/dcs-runtime-traps.md`.

## Tickets

| # | Ticket | Status |
|---|---|---|
| [01](tickets/01-wrap-modules.md) | Each module in its own block, and a test that runs the bundle | ✅ |
