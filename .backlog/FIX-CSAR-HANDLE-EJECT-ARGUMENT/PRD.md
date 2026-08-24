# FIX-CSAR-HANDLE-EJECT-ARGUMENT — CSAR hands a player name to a function that indexes a unit

Status: ✅ done

Found on 2026-08-22 while shipping
[`FIX-CSAR-SPAWNS-ON-WATER`](../FIX-CSAR-SPAWNS-ON-WATER/PRD.md), because that lot had to reproduce the
call and looked at what it does. Fixed on 2026-08-24.

## The defect

`csar.addCsar` (`CSAR.lua:384`) calls:

```lua
csar.handleEjectOrCrash(_playerName, false)
```

`handleEjectOrCrash(_unit, _crashed)` (`CSAR.lua:628`) immediately does `_unit:getName()`,
`_unit:getPlayerName()` and `_unit:getID()`. A **player name is a string**, so this raises
*"attempt to index a string value"*.

It is invisible today because `csar.csarMode` defaults to **0**, and every branch of the function is
gated on a non-zero mode. A mission that sets the mode — which is the whole point of the setting,
disabling an aircraft or a pilot after an ejection — gets an error instead of the sanction it asked for.

Every other caller passes a unit: `csar.handleEjectOrCrash(_unit, true)` from the crash handler. Only
`addCsar` passes the name.

## Three modes, not two

Correcting this PRD's own first draft, which said two: reading the vendored function through shows
**three** sanctions, and they do not need the same information.

| `csar.csarMode` | What it does | Needs |
|---|---|---|
| 0 (default) | nothing | — |
| 1 | disables the aircraft for everyone, via a `CSAR_AIRCRAFT<id>` flag | the **aircraft**: `getID()` |
| 2 | disables that aircraft for that pilot, same flag keyed on the player too | the **aircraft** |
| 3 | reduces the pilot's lives | the **pilot**: `getPlayerName()` |

That distinction is what makes the fix decidable rather than a guess. A player name is strictly less
than a unit, so a replacement cannot always serve all three.

## Local replacement, not upstream

Decided with David on 2026-08-24: **local replacement**. `CSAR.lua` is vendored `adapted`, so an edit
in place is erased by the next update, and upstream was measured to be a dead end — `VEAF/DCS-CSAR` is
`ahead=0 behind=0` on `ciribob/DCS-CSAR` and both have been untouched since August 2023. Sending a PR
into a repository nobody merges is not a fix, it is a hope.

`veaf.replaceCsarHandleEjectOrCrash()` (`src/scripts/veaf/veaf.lua`) is installed from
`veaf.csar_initialize_replacement`, next to `veaf.replaceCsarAddCsar()`, with the same idempotence
guard. It behaves as follows:

- a **unit** is passed straight through, so every existing caller is unaffected;
- a **name** is resolved to the player's unit through `coalition.getPlayers` when he is still flying,
  and then passed through — the full sanction is available;
- when it cannot be resolved, **mode 3 is still served** from the name alone, while modes 1 and 2 are
  **refused with a warning**. They key on the aircraft's `getID()`, and inventing one would ground an
  aircraft nobody chose. A skipped sanction is recoverable; a misapplied one is not.

`coalition.getPlayers` was absent from `test/lua/dcs_mocks.lua`, which is why nothing could test a
player-name lookup; it is in the real API (`dcs-world-api.lua:1395`) and is now mocked.

## The `pcall` kept, and a test that was right by accident

The over-water wrapper's `pcall` around this call stays. It no longer guards a defect we know about —
it guards the next one, in a vendored function, on the path that runs while a pilot is drowning. Its
comment said the call *does* raise, which is now false, so it was corrected. A new test asserts the
lost-at-sea path applies the mode-3 sanction for real and that the `pcall` reports nothing.

Found while proving the above: `TestEveryChunkCompiles` (`test/python/veaf_libs/test_dcs_smoke.py`)
resolved its interpreter with `shutil.which("lua")`. This machine has two — a scoop 5.5.0 shim and the
5.1.5 in Program Files — and which one wins depends on the PATH of the shell that launched pytest. It
answered 5.1.5, so the check was right by accident. It now goes through
`veaf_build.lua_tests._find_lua`, which version-checks. A 5.5 rejects valid 5.1 and accepts syntax DCS
would not, so the same test could have reported failures that are not defects.

## Definition of done

- [x] Decide between the upstream PR and a local replacement — with David, since it is his fork
- [x] A mission with `csarMode` 1 or 2 gets the disablement it asked for, tested
- [x] The `pcall` guard in the over-water wrapper revisited once the call cannot raise

Sixteen Lua tests, and three mutations run against them to prove they can fail: removing the
replacement kills eight, serving modes 1/2 with a stub kills two, and matching a player by anything
other than his name kills one.
