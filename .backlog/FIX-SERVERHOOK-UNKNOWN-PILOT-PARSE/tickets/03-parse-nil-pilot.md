# 03 — Deny an unlisted pilot instead of crashing

Status: ✅ done

## Context

`veafServerHook.parse` logs the "Unknown pilot" warning for a pilot absent from the
list but keeps going and then reads `pilot.level`, throwing
`attempt to index local 'pilot' (a nil value)` (`VEAF-Server-hook.lua:413`). Observed
3× when an unlisted pilot sent `/secu login`.

## Change

In the `if not pilot then` guard, assign the no-power sentinel already used by
`onPlayerConnect`:

```lua
pilot = { level = -1 } -- unknown pilot: no power at all (same convention as onPlayerConnect)
```

Every command threshold is `>= 0` or higher, so `level = -1` is denied everywhere and
`parse` returns `false` without touching a `nil` value.

## Done when

- An unlisted pilot sending any `/command` is cleanly denied; no Lua error is raised.
