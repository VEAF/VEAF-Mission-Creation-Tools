# Module initialisation — what actually starts a VEAF module

Read this before adding a module, moving a `veaf.registerModule` order, or touching
`_MODULE_INIT_ORDER`. Three mechanisms start VEAF modules, only one of them runs today, and the
declared orders of the other one do not describe it.

The table below is checked by `test/python/veaf_libs/test_module_init_registry.py`: it is read back
from this file and compared against the Lua sources and the generator, so it cannot quietly go
stale. When the test fails, fix the code or update the table — do not delete the assertion.

## The three mechanisms {#mechanisms}

1. **`veaf.registerModule(id, initFn, defaults, order)`** — the registry, in `veaf.lua`. It merges
   the module's defaults into `veaf.config[id]`, guarantees `enable`, and stores
   `veaf.modules[id] = { initFn, order }`. That store is read by exactly one function,
   `veaf.initialize()`, **which nothing calls**. The registry is therefore inert: today its `order`
   argument is a statement of intent, not a sequence anything obeys.

2. **The generated `veaf-config.lua`** — produced by `lua_config_generator.py` at build time. It
   calls each module's `initialize()` one by one, in `_MODULE_INIT_ORDER`, and **only for the
   modules the mission enables**. This is what actually orders a mission's start-up. A module with
   no place in that list is still called when the mission enables it — it lands in the unordered
   bucket just before `INTERPRETER`.

3. **Self-initialisation at load** — the module file calls its own `initialize()` on the last lines,
   so it works even in a mission that generates no config. `veafMissionDb` and `veafEventHandler`
   both do it, deliberately, and say why in place. Both are then initialised a second time by
   mechanism 2; `veafEventHandler` guards its `world.addEventHandler` against exactly that.

A fourth thing looks like a module and is not: **CTLD**. `veaf.lua` registers it
(`veaf.registerModule(veaf.ctldId, veaf.ctld_initialize, …, 50)`) but it is a community script, not
a VEAF module — the generator starts it from its own block, before the module block. See
[ADR 0016](../adr/0016-ctld2-sidecar-configuration.md).

## The table {#table}

`Registry order` is the 4th argument of `veaf.registerModule`. `Generator position` is the index in
`_MODULE_INIT_ORDER`. `--` in either column means the module is absent from that mechanism; the
[divergences](#divergences) section explains every one of them.

<!-- MODULE-INIT-TABLE-START -->
| Module ID | Lua table | Registry order | Generator position | Self-init | `initialize()` |
| --- | --- | --- | --- | --- | --- |
| `AIRBASES` | `veafAirbases` | 200 | 18 | -- | `initialize(bReset)` |
| `AIRWAVES` | `veafAirWaves` | -- | 13 (data only) | -- | -- |
| `ASSETS` | `veafAssets` | 160 | 12 | -- | `initialize()` |
| `ASSIST` | `veafAssist` | 145 | 21 | -- | `initialize()` |
| `CACHE` | `veafCacheManager` | 3 | 24 | -- | `initialize()` |
| `CARRIER` | `veafCarrierOperations` | 80 | 5 | -- | `initialize()` |
| `CASMISSION` | `veafCasMission` | 90 | 6 | -- | `initialize()` |
| `COMBATMISSION` | `veafCombatMission` | 100 | 8 | -- | `initialize()` |
| `COMBATZONE` | `veafCombatZone` | 110 | 9 | -- | `initialize()` |
| `COMMANDS` | `veafCommands` | 15 | -- | -- | `initialize()` |
| `EVENTS` | `veafEventHandler` | 10 | 25 | yes | `initialize()` |
| `GEO` | `veafGeo` | -- | -- | -- | `initialize()` |
| `GRASS` | `veafGrass` | 150 | 11 | -- | `initialize()` |
| `GROUNDAI` | `veafGroundAI` | 190 | 26 | -- | `initialize()` |
| `I18N` | `veafI18n` | -- | -- | -- | -- |
| `INTERPRETER` | `veafInterpreter` | 170 | 29 | -- | `initialize()` |
| `MARKERS` | `veafMarkers` | 4 | 19 | -- | `initialize()` |
| `MATH` | `veafMath` | -- | -- | -- | `initialize()` |
| `MISSILEGUARDIAN` | `veafMissileGuardian` | 180 | 20 | -- | `initialize()` |
| `MISSIONDB` | `veafMissionDb` | 5 | -- | yes | `initialize()` |
| `MOVE` | `veafMove` | 60 | 14 | -- | `initialize()` |
| `NAMEDPOINTS` | `veafNamedPoints` | 50 | 3 | -- | `initialize(customPoints)` |
| `QRA` | `veafQraManager` | 130 | 10 | -- | `initialize()` |
| `RADIO` | `veafRadio` | 30 | 1 | -- | `initialize(skipHelpMenus, dontCreateMenus)` |
| `REMOTE` | `veafRemote` | 230 | 17 | -- | `initialize()` |
| `SANCTUARY` | `veafSanctuary` | 140 | 15 | -- | `initialize()` |
| `SCHEDULER` | `veafScheduler` | -- | -- | -- | `initialize()` |
| `SECURITY` | `veafSecurity` | 20 | 0 | -- | `initialize()` |
| `SHORTCUTS` | `veafShortcuts` | 40 | 2 | -- | `initialize()` |
| `SKYNET` | `veafSkynet` | 220 | 27 | -- | `initialize(includeRedInRadio, debugRed, includeBlueInRadio, debugBlue)` |
| `SKYNET_MONITOR` | `veafSkynetMonitor` | 225 | 28 | -- | `initialize()` |
| `SPAWN` | `veafSpawn` | 70 | 4 | -- | `initialize()` |
| `SPAWNER` | `veafDcsSpawner` | -- | -- | -- | `initialize()` |
| `TIME` | `veafTime` | 2 | 22 | -- | `initialize()` |
| `TRANSPORTMISSION` | `veafTransportMission` | 120 | 7 | -- | `initialize()` |
| `UNITS` | `veafUnits` | 1 | 23 | -- | `initialize()` |
| `WEATHER` | `veafWeather` | 210 | 16 | -- | `initialize(bWelcomeBrief)` |
<!-- MODULE-INIT-TABLE-END -->

Four registrations wrap their init in a closure that reads the config first — `NAMEDPOINTS`,
`RADIO`, `SKYNET`, `WEATHER`. For those, "call `initFn`" is not "call `<module>.initialize()`":
the closure reads `veaf.getConfig(id)` and forwards the values as arguments. The generator passes
the same values positionally, from `_MODULE_INIT_PARAMS` and its per-module branches.

## The divergences, and why each one exists {#divergences}

### Deliberate

- **`AIRWAVES` is in the generator's order but never registers.** It has no `initialize()` at all:
  a mission declares `VeafAirWaveZone:new()…:start()` chains and there is nothing global to start.
  Its slot in `_MODULE_INIT_ORDER` places the emitted *data*; `_NO_INIT_MODULES` suppresses the
  init call.
- **`GEO`, `I18N`, `MATH`, `SCHEDULER`, `SPAWNER` are in neither list.** They are libraries: they
  publish their functions onto `veaf.*` when their file loads. `veafI18n` has no `initialize()`;
  the other four have one that logs a line and does nothing else.
- **`EVENTS` and `MISSIONDB` initialise themselves at load.** Both are read from the top level of
  other modules' files, so waiting for an init pass would be too late. Both are then initialised a
  second time by the generated config, which is why `veafEventHandler` guards its DCS event-handler
  registration.
- **`UNITS`, `TIME`, `CACHE`, `MARKERS` register at orders 1–4** although their `initialize()` does
  nothing but log. They are mandatory infrastructure that the generated config already calls on
  every mission; the registry used to omit them, which made it describe a framework that does not
  exist. Their order cannot be wrong, because they have no start-up work to order.

### Accidental, and left alone on purpose

- **`COMMANDS` (order 15) and `MISSIONDB` (order 5) have no declared place in
  `_MODULE_INIT_ORDER`.** They fall into the generator's unordered bucket, near-last — `COMMANDS`
  after every command module, `MISSIONDB` as a second snapshot rebuild. Harmless today (a command
  module registers through `veafCommands.registerCommandHandler`, which only inserts into a table
  declared at load), but the declared intent and the actual sequence disagree. Giving them a place
  changes what every mission's `veaf-config.lua` contains, so it belongs to the lot that flips the
  switch, not here.
- **`veafI18n` has no `initialize()` and is not in `_NO_INIT_MODULES`.** `I18N` appears in the
  generated `mission.yaml` template like every other module, so a mission that enables it gets
  `veafI18n.initialize()` emitted — a call to a nil value, which DCS reports at mission start.
  Pinned by the test as a known gap rather than fixed here: fixing it changes generated output.

### The one that matters for the switch {#switch-risk}

The registry's declared orders and the generator's positions are **two different orders**, and they
disagree for most of the tree. Sorting the 29 modules present in both mechanisms gives:

- by registry order: `UNITS, TIME, CACHE, MARKERS, EVENTS, SECURITY, RADIO, SHORTCUTS, NAMEDPOINTS,
  MOVE, SPAWN, CARRIER, CASMISSION, COMBATMISSION, COMBATZONE, TRANSPORTMISSION, QRA, SANCTUARY,
  ASSIST, GRASS, ASSETS, INTERPRETER, MISSILEGUARDIAN, GROUNDAI, AIRBASES, WEATHER, SKYNET,
  SKYNET_MONITOR, REMOTE`
- by generator position: `SECURITY, RADIO, SHORTCUTS, NAMEDPOINTS, SPAWN, CARRIER, CASMISSION,
  TRANSPORTMISSION, COMBATMISSION, COMBATZONE, QRA, GRASS, ASSETS, MOVE, SANCTUARY, WEATHER, REMOTE,
  AIRBASES, MARKERS, MISSILEGUARDIAN, ASSIST, TIME, UNITS, CACHE, EVENTS, GROUNDAI, SKYNET,
  SKYNET_MONITOR, INTERPRETER`

The sharpest case: `_MODULE_INIT_ORDER` says *INTERPRETER **must** remain last*, and the registry
puts it at 170 — ahead of `MISSILEGUARDIAN`, `GROUNDAI`, `AIRBASES`, `WEATHER`, `SKYNET`,
`SKYNET_MONITOR` and `REMOTE`. (`veafInterpreter.initialize()` only *schedules* its real work
`DelayForStartup` seconds later, so the constraint is softer than it reads — but the registry still
contradicts the generator's own stated invariant.)

Making the generated config call `veaf.initialize()` therefore reorders most of the tree unless the
declared orders are reconciled first. That reconciliation is the second lot's job, and this table
is the input it needs.
