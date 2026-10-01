# 03 — call the completion hook of an operation

Status: ✅ done

Files: `src/scripts/veaf/veafCombatZone.lua`, `test/lua/test_veafCombatZone.lua`.

`VeafCombatOperation:setOnCompletedHook` stored the function, and nothing called it: the operation
replaces the zone's `completionCheck`, which is where a zone calls its own hook, and
`updatePrimaryTasks` ended the operation (message, `desactivate`) without it.

## Done when

- `updatePrimaryTasks`, when no task is left, calls the hook with the operation, after the message.
- A luaunit test drives an operation with no task left and sees the hook called.
