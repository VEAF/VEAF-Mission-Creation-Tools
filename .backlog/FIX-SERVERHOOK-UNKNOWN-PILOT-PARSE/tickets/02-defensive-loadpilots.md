# 02 — Stop crashing on a missing/invalid pilots file

Status: ✅ done

## Context

`local file = assert(loadfile(filepath))` throws when the file is absent, so the
`if not file then logError ... return end` branch right below is unreachable dead
code and the failure surfaces as a raw Lua exception
(`LuaHooks ...:557: no file '...'`).

## Change

Replace `assert(loadfile(...))` with a checked `loadfile` capturing the error:

```lua
local file, err = loadfile(filepath)
if not file then
    veafServerHook.logError(string.format("Cannot load pilots list file [%s]: %s -- no pilot will be recognized and every command will be denied", veafServerHook.p(filepath), veafServerHook.p(err)))
    return
end
```

## Done when

- A missing or invalid pilots file logs a clear VEAF error and leaves the hook
  running (pilots table stays as-is), instead of raising a Lua exception.
