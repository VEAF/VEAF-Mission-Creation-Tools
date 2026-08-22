# FIX-REMOTE-DEAD-MARKER-HANDLER — every marker with text answered "your command failed"

Status: ✅ done — shipped in 6.15.30

Reported in game on 2026-08-22, mid-session, as an aside: *"on ne peut pas mettre de simple marqueur
(sans volonté de lancer une commande) sans avoir une erreur"*. Not a side note — it had been true for
eleven days.

## What happened

`veafRemote.initialize()` registered a marker command handler:

```lua
veafCommands.registerCommandHandler(function(pos, event, ...)
  return veafRemote.executeCommand(pos, event.text)
end, veafCommands.PRIORITY_REMOTE, veafCommands.SECURITY_HANDLED)
```

`veafRemote.executeCommand` was **deleted on 2026-08-11** (`9a20c50c`, the security review) along with
`markTextAnalysis` and `executeRemoteCommand` — the mechanism that accepted a shared password typed into
marker text, replaced on purpose by `registerRemoteModule` / `executeCommandFromRemote`, which
authenticates a named user. The registration was left behind.

`veafMarkers.onEvent` calls **every** registered handler for any marker carrying text, each under
`pcall`, and reports a failure to the pilot when one raises. So every annotation on the map produced:

```
Error in event handler #2 : attempt to call field 'executeCommand' (a nil value)
```

and, in game, *"VEAF: your marker command failed (see the DCS log for details)"*.

The pilot-facing message dates from 2026-06-13, so it was not the cause — it is what made an existing
silent breakage visible. Without it this would have sat in the log indefinitely.

## What shipped

Both survivors of the removal are gone:

- the handler registration in `initialize`, which is what broke markers
- `veafRemote.addNiodCommand`, which called the same deleted function. It had **no caller** in the
  scripts, the tests or the docs, so it never raised — it was simply the other half of the unfinished
  removal, and leaving it would have left a second one waiting

## The test that matters more than the fix

`test/python/test_lua_module_calls_resolve.py` sweeps every `veafX.y(...)` call in the scripts and fails
when it reaches a function nothing defines. Lua cannot catch this: a missing table field is `nil` until
something calls it, and that call dies inside a `pcall` nobody reads.

Verified by re-introducing the dead call and watching the sweep name it, then removing it again — the
check is not passing by accident. Strings and comments are stripped first, because three of the first
five hits were log labels like `string.format("veaf.getAirbaseforCoalition(...)")` and code inside a
`[[ ]]` block. A checker that cries wolf gets ignored, which is worse than not having one.

The sweep found **one** further genuine offender across 1166 defined symbols, filed as
[`FIX-MISSILEGUARDIAN-NO-STORAGE`](../FIX-MISSILEGUARDIAN-NO-STORAGE/PRD.md) and listed in the test's
`KNOWN_MISSING` ratchet rather than silently skipped.

## Definition of done

- [x] A marker carrying arbitrary text raises nothing and reports nothing
- [x] Both references to the deleted function are gone
- [x] Lua tests pin the **absence** of `executeCommand` and `addNiodCommand`, and that `initialize`
      registers no command handler — re-adding them would be a security regression, not a feature
- [x] A repo-wide sweep catches the whole class, proven against the real defect
