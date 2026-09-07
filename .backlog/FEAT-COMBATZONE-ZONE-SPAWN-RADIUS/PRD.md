# FEAT-COMBATZONE-ZONE-SPAWN-RADIUS — the dispersion default, settable from `mission.yaml`

Status: ✅ done

Origin: Tripack, relayed by David on 2026-09-07. He places air defences in the revetments the Syria
map draws for exactly that purpose, and a spawn that scatters a launcher by tens of metres puts it on
the berm instead of inside it. His ask: *"une option sur les CZ pour changer le default de
spawnradius. Comme ça il peut mettre 0 pour les CZ où il a beaucoup d'objets placés pile poil."*

## The first version of this PRD was wrong, and David caught it

It proposed `VeafCombatZone:setDefaultSpawnRadius(0)` as *"one line in the fluent chain the mission
maker already writes"*, and said the mission-wide default was already available as
`veafCombatZone.DefaultSpawnRadiusForUnits = 0`. David's question — *"pas de YAML pour ce param ?"* —
is the one that mattered.

**Tripack does not write that chain.** His `veaf-config.lua` opens with:

```
-- Généré par veaf-tools build depuis mission.yaml
-- Ne pas éditer manuellement.
```

The chain is emitted by `_emit_combat_zone_def`
([`lua_config_generator.py:733`](../../src/python/veaf-tools/veaf_libs/lua_config_generator.py)), and
anything he types into the generated file is gone at the next `build`. There is **no `default_spawn_radius`
key in `mission.yaml`** at either level, and **no raw-Lua escape hatch** in the schema — checked, none.

So the honest statement of today's situation is the opposite of what the first draft said: a mission
maker on the YAML workflow **cannot set this default at all**. Tagging every group of every pinned
zone with `#spawnradius=0` is the only route open to him.

## Where it goes, and why it is two tickets

`mission.yaml` already carries both levels for this module, so no new structure is needed:

```yaml
COMBATZONE:
  combat_zone_settings:      # ← mission-wide, already holds watchdog_check_interval, radio_menu_name…
    default_spawn_radius: 0
  combat_zones:              # ← per zone, already holds friendly_name, radio_group_name…
    - zone_name: CMBT_PALMYRA
      default_spawn_radius: 0
```

The mission-wide key is nearly free: `watchdog_check_interval` → `veafCombatZone.SecondsBetweenWatchdogChecks`
is the exact same shape, three lines in the generator, and **no Lua change at all** — the global it
assigns already exists and is already documented. The per-zone key needs a Lua setter as well, since
there is nothing to assign per zone today. Hence one ticket each, the cheap and immediately useful one
first.

## Precedence

| Level | Written as | Wins over |
|---|---|---|
| the group | `#spawnradius=N` on a group or unit name | everything |
| the zone | `default_spawn_radius` under a `combat_zones` entry | the mission-wide key |
| the mission | `default_spawn_radius` under `combat_zone_settings` | the built-in default (50 / 0) |

The group level already works, and since FIX-TRIPACK-FIELD-REPORTS ticket 04 a written zero is a true
**identity spawn** — asserted to the millimetre in `test_veafCombatZone_displacement.lua`. Before that
ticket the tag alone was not enough: the anchor offset applied whatever the radius, which
`veafCombatZone.lua` admitted in its own comment (*"the delta is not only the dispersion"*).

## Rejected: a tag in the trigger zone's name

It would read naturally, the way `#spawnradius=` goes on a group. But a combat zone's name is
load-bearing: every group belonging to it must carry that name as a **prefix**, and the zone reports
the ones that do not (`reportGroupsExcludedByName`, which fired in Tripack's own log). Tagging the
zone name would either break that rule or force it to start stripping tags — a change to the naming
contract of every existing mission. And it would not help him anyway: his zone names come out of
`mission.yaml` too.

## Scope

| # | Ticket | Type |
|---|--------|------|
| 01 | [The mission-wide default comes from `mission.yaml`](tickets/01-mission-wide-yaml-key.md) | feat |
| 02 | [A zone carries its own default](tickets/02-zone-level-spawn-radius-default.md) | feat |

## Constraints

- **Defaults lockstep** (CLAUDE.md §9.7): both tickets change what `lua_config_generator` emits, so
  `src/defaults/mission-folder/mission.yaml` is updated in the same lot — the shipped default must
  document the new keys where a mission maker will actually meet them.
- The distinction FIX-COMBATZONE-DEAD-SPAWN-RADIUS-DEFAULT established has to survive: a default is
  applied because the tag was **not written**, never because its value happens to be 0. `0` must stay
  a legitimate written value at every level, which rules out the `if x :=` truthiness test the
  generator uses for its other keys — `if default_spawn_radius := cz_settings.get(...)` silently drops
  exactly the value Tripack wants.
- **Both languages** for the documentation, in lockstep, `poetry run docs-check` clean.
- Any test asserting dispersion must drive `dcs_mocks.setRandomSequence`: the mocks answer
  `math.random()` with a constant 0, so in the harness no spawn ever scatters and a dispersion
  assertion passes whichever way it is written. Found the hard way in FIX-TRIPACK-FIELD-REPORTS
  ticket 04.

## Delivered

Both tickets, one branch, one PR. What went in:

- `lua_config_generator` reads `default_spawn_radius` / `default_spawn_radius_statics` at both levels
  **by presence**, and the per-zone pair is emitted into the chain before `:initialize()`.
- `VeafCombatZone:setDefaultSpawnRadius` / `…ForStatics`, resolved at element-build time by
  `resolveDefaultSpawnRadius` so a global assignment and an `AddZone` call are order-independent.
  `buildGroupElement` takes the zone as an optional fourth argument, which leaves every existing
  caller — and the tests that build an element outside a zone — on the module globals.
- A call after `initialize()` is refused with a logged error rather than ignored.

**Both test suites were verified to fail**, which is the only reason to trust them:

| Mutation | What fell |
|---|---|
| generator back to `if x := cfg.get(...)` | the 4 Python tests asserting `0`, and only those |
| the zone unplugged from `buildGroupElement` | 4 of the 9 Lua tests |

One thing found and **not** turned into a change: `~= nil` versus `or` in `resolveDefaultSpawnRadius`
is not a fix in Lua, because `0` is truthy there — no test can tell the two apart. The comment that
claimed otherwise was corrected rather than left to mislead the next reader; the real version of that
trap lives on the Python side, where `0` *is* falsy, and it is what ticket 01's tests exist to catch.
