# 04 — retire `veaf.ctld_initialize_replacement`, route the logs, own the init

**Status:** ✅ done

Depends on 03.

## What changes

Delete [veaf.lua:4490-4674](../../../src/scripts/veaf/veaf.lua) — the whole "changes to CTLD" block,
~185 lines — and put back, in its place:

```lua
if ctld and veaf.isEnabled("ctld") then
  -- one override replaces the seven of v1 (ctld.p, Id, logger, logError/Info/Debug/Trace):
  -- CTLD 2 routes all 241 of its log calls through ctld.utils.log.
  local _l = veaf.loggers.new("CTLD", ...)
  ctld.utils.log = function(level, fmt, ...) --[[ map level → VEAF method, then delegate ]] end
  ctld.initialize()
end
```

Three details that will bite otherwise:

- **Level names do not map 1:1** — CTLD emits `INFO` / `WARN` / `ERROR` / `DEBUG`, VEAF's logger has
  `warn` where CTLD says `WARN`. Write the mapping table explicitly and default unknown levels to
  `info` rather than indexing nil.
- **The override must be in place before `ctld.initialize()`**, or the startup report — the whole
  reason for taking control of the init (PRD decision 5) — is written before the logger exists.
- **`configurationCallback` disappears.** No caller replaces it: mission-specific configuration now
  lives in `ctld-config.yaml`.

The `veaf.ctld_initialize` / `veaf.ctld_initialized` globals go with the block. Grep for them first
— a mission script in the wild may reference them, in which case the removal is worth a line in the
migration guide (ticket 06).

Also fix the two stale help messages in
[veafTransportMission.lua:715](../../../src/scripts/veaf/veafTransportMission.lua), which tell the
user to call `ctld.autoInitializeAllHumanTransports` / `autoInitializeAllLogistic` — both gone.

## Acceptance

- CTLD initialises once, after the VEAF logger is in place, and its startup report appears in the
  VEAF log channel.
- `CTLD: false` → CTLD is neither bundled nor initialised, and nothing errors.
- No reference to `ctld_initialize_replacement` remains.

## Tests

- Lua (`poetry run test-lua`): the log override maps each level, unknown level → `info`.
- Lua: `initialize()` is called exactly once, after the override.
- The CTLD mock in `test/lua/dcs_mocks.lua` needs updating to the v2 surface — it currently models v1
  globals.
