# 01 — The mission-wide default comes from `mission.yaml`

Status: ⬜ ready

Type: feat

## What it is

A `default_spawn_radius` key under `combat_zone_settings`, emitted as an assignment to the module
global that already exists:

```yaml
COMBATZONE:
  combat_zone_settings:
    default_spawn_radius: 0        # every zone of this mission places its groups exactly as drawn
```

```lua
veafCombatZone.DefaultSpawnRadiusForUnits = 0
```

No Lua change. `veafCombatZone.DefaultSpawnRadiusForUnits` is a plain module global
([`veafCombatZone.lua:36`](../../../src/scripts/veaf/veafCombatZone.lua)), already read by
`buildGroupElement` when a group carries no tag, and already documented for mission makers
([`veafCombatZone.md:508`](../../../doc/mission-maker/scripts/veafCombatZone.md)). The only thing
missing is the key that reaches it — which is why this ticket exists at all and why it is small.

`watchdog_check_interval` → `veafCombatZone.SecondsBetweenWatchdogChecks` is the same shape, three
lines away in the same function
([`lua_config_generator.py:681`](../../../src/python/veaf-tools/veaf_libs/lua_config_generator.py)).
Follow it.

## The one trap, and it is the whole point of the ticket

Every neighbouring key is read with a truthiness walrus:

```python
if wci := cz_settings.get("watchdog_check_interval"):
```

`0` is falsy in Python, so written that way `default_spawn_radius: 0` — **the only value Tripack
actually asked for** — would be silently dropped and the built-in 50 would apply. The key has to be
read with a presence test (`if "default_spawn_radius" in cz_settings`), the way
`event_message_combatzonecomplete` already handles its explicit `None`.

This repository has been bitten by the same class of mistake in Lua: `not 0` is false there too, and
it is what made `#spawnradius=0` indistinguishable from "unstated" for three years
(FIX-COMBATZONE-DEAD-SPAWN-RADIUS-DEFAULT). Same bug, other language.

## Statics

The global comes as a pair — `DefaultSpawnRadiusForUnits` (50) and `DefaultSpawnRadiusForStatics`
(0). A single YAML key that wrote both would silently start scattering statics that are pinned today.
So: `default_spawn_radius` sets the **unit** default, and `default_spawn_radius_statics` is offered
alongside it for completeness. Decide it explicitly in the code comment rather than leaving a reader
to wonder which one moved.

## Definition of done

- [ ] `default_spawn_radius: 0` in `combat_zone_settings` reaches the generated config and applies
- [ ] A Python test asserts **0 specifically**, not just some value — the truthiness trap is the
      reason for the ticket, so the test has to be able to catch it
- [ ] `default_spawn_radius_statics` handled, with the pair's reason in the comment
- [ ] An absent key changes nothing in the generated output (byte-identical against the current
      generator on an existing `mission.yaml`)
- [ ] `src/defaults/mission-folder/mission.yaml` documents both keys in the `COMBATZONE` block
      (defaults lockstep, CLAUDE.md §9.7)
- [ ] `doc/mission-maker/scripts/veafCombatZone.md` **and** `.en.md` document the key and its
      precedence; `poetry run docs-check` clean
- [ ] ruff + ruff format + mypy clean over the whole Python tree, as CI runs them
