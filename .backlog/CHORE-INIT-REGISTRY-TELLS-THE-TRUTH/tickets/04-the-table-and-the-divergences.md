# 04 — The table, and every divergence explained

Status: ✅ done

Type: doc · Files: `docs/agents/module-initialisation.md`, `src/scripts/veaf/veaf.lua`,
`src/scripts/veaf/veafAirWaves.lua`, `src/scripts/veaf/veafCommands.lua`,
`src/scripts/veaf/veafMissionDb.lua`, `src/python/veaf-tools/veaf_libs/lua_config_generator.py`

## Where the table lives, and why there

`docs/agents/module-initialisation.md`, beside `dcs-coordinates.md` — the directory `CLAUDE.md` already
sends an agent to before it writes code that can be wrong in a way tests do not catch. Thirty-seven
rows do not belong in a source comment, and `doc/` is the mission-maker site: nothing here is
mission-maker facing.

The two places where the mistake actually gets made carry a pointer instead of a copy:
`veaf.registerModule`'s docstring in `veaf.lua`, and `_MODULE_INIT_ORDER` in
`lua_config_generator.py`. Each says the one thing that is invisible from where it sits — that the
registry is inert, and that the generator's list is what really orders a mission.

The table is **read back by the test**, so it cannot go stale on its own.

## The divergences

Deliberate, written down where the code is:

- `AIRWAVES` — in the generator's order, never registers: it has no `initialize()`; a mission declares
  `VeafAirWaveZone` chains and there is nothing global to start.
- `GEO`, `I18N`, `MATH`, `SCHEDULER`, `SPAWNER` — in neither list: libraries that publish onto
  `veaf.*` at load.
- `EVENTS`, `MISSIONDB` — self-initialise at load, then again from the generated config.
  `veafEventHandler` guards its DCS registration against exactly that; `veafMissionDb` already
  explained itself and now also says what the second call is.
- `UNITS`, `TIME`, `CACHE`, `MARKERS` at orders 1–4 — see ticket 02.

Accidental, recorded and deliberately not fixed here because the fix changes generated output:

- `COMMANDS` (15) and `MISSIONDB` (5) hold no place in `_MODULE_INIT_ORDER`, so the generator calls
  them from its unordered bucket, near-last. `veafCommands.lua`'s comment claimed the opposite and now
  says what happens.
- `veafI18n` has no `initialize()` and is not in `_NO_INIT_MODULES`, so a mission that enables `I18N`
  gets a call to a nil value. Pinned by an assertion so the fix must come with a doc update.

## Definition of done

- [x] One table, in the repository, covering all 37 modules across the three mechanisms
- [x] Every divergence labelled deliberate or accidental, with its reason
- [x] Deliberate ones written where the code is, as `veafMissionDb` already did
- [x] The registry/generator order disagreement recorded in full, as the second lot's input
