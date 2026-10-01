# 01 — the event bus subscribes the destroyed-scenery register

Status: ✅ done

Files: `src/scripts/veaf/veafMissionDb.lua`, `src/scripts/veaf/veafEventHandler.lua`,
`test/lua/test_veafMissionDb_scenery.lua`.

`veafMissionDb` is loaded before `veafEventHandler`, so its load-time `initialize` finds no bus. The
code counted on a second `initialize` on the module init pass, which the generator only emits for a
mission listing `MISSIONDB` — none does. Since #836 (2026-08-28) the register recorded nothing, so the
Combat Missions' *prevent destruction of map objects* objective could never fail. The wiring tests
called `veafMissionDb.initialize()` by hand, which no mission does.

## Done when

- `veafMissionDb.registerSceneryCallback` is public; `veafEventHandler.initialize` calls it once the
  bus exists. The guard keeps the two callers from subscribing twice.
- Tests: the bus alone subscribes the register; bus + register + bus again subscribe once.
